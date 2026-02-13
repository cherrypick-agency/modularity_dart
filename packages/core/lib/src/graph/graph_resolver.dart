import 'dart:async';
import 'package:modularity_contracts/modularity_contracts.dart';
import '../engine/module_controller.dart';
import '../engine/module_override_scope.dart';
import 'module_registry_key.dart';

/// Resolves the module import graph and initializes dependencies
/// concurrently.
///
/// For each import declared by a [Module], the resolver:
/// 1. Checks for circular dependencies using a per-branch [resolutionStack].
/// 2. Looks up (or creates) a [ModuleController] in the shared [registry]
///    to avoid duplicate initialization.
/// 3. Initializes the controller if it has not started yet, or waits for
///    an in-progress initialization triggered by a concurrent branch.
///
/// All import branches are resolved in parallel via [Future.wait],
/// maximizing throughput for large module graphs.
///
/// See also:
/// - [ModuleController.initialize] which delegates to this resolver.
/// - [ModuleRegistryKey] for identity semantics.
class GraphResolver {
  /// Recursively resolves and initializes the imports of [module].
  ///
  /// Returns the list of [ModuleController]s for the direct imports.
  /// Throws [CircularDependencyException] or [ModuleLifecycleException]
  /// if resolution fails.
  Future<List<ModuleController>> resolveAndInitImports(
    Module module,
    Map<ModuleRegistryKey, ModuleController> registry,
    BinderFactory binderFactory, {
    Set<Type>? resolutionStack,
    List<ModuleInterceptor> interceptors = const [],
    ModuleOverrideScope? overrideScope,
  }) async {
    final currentStack = resolutionStack ?? {module.runtimeType};

    // 1. Prepare all tasks (Futures) and launch them concurrently
    final futures = module.imports.map((importModule) async {
      final type = importModule.runtimeType;

      // Check Circular Dependency (Immediate Fail-Fast)
      if (currentStack.contains(type)) {
        throw CircularDependencyException(
          'Circular dependency detected: ${currentStack.join(' -> ')} -> $type',
          dependencyChain: [...currentStack, type],
        );
      }

      // --- CRITICAL SECTION START (Synchronous) ---
      // Important: Getting or creating the controller must be atomic
      // so that concurrent branches don't create duplicates.
      // In Dart this block won't be preempted as long as there's no await.
      final childScope = overrideScope?.childFor(type);
      final registryKey = ModuleRegistryKey(
        moduleType: type,
        overrideScope: childScope,
      );
      ModuleController? controller = registry[registryKey];

      if (controller == null) {
        controller = ModuleController(
          importModule,
          binderFactory: binderFactory,
          overrideScopeTree: childScope,
          interceptors: interceptors,
        );
        registry[registryKey] = controller;
      }
      // --- CRITICAL SECTION END ---

      // Branch A and Branch B each get their own copy of the stack.
      // This allows safe cycle detection across concurrent branches.
      final newStack = {...currentStack, type};

      // Now it's safe to await (yield execution)
      if (controller.currentStatus == ModuleStatus.initial) {
        await controller.initialize(registry, resolutionStack: newStack);
      } else if (controller.currentStatus == ModuleStatus.loading) {
        // If the module is already loading (triggered by another branch), just wait.
        // Check for cycles in THIS branch
        if (currentStack.contains(type)) {
          throw CircularDependencyException(
            'Circular dependency detected (during loading): ${currentStack.join(' -> ')} -> $type',
            dependencyChain: [...currentStack, type],
          );
        }
        // Smart Wait: Wait until the other branch finishes
        await controller.status.firstWhere(
          (s) =>
              s == ModuleStatus.loaded ||
              s == ModuleStatus.error ||
              s == ModuleStatus.disposed,
        );

        if (controller.currentStatus == ModuleStatus.error) {
          throw ModuleLifecycleException(
            'Dependent module $type failed to load: ${controller.lastError}',
            moduleType: type,
            state: ModuleStatus.error,
          );
        }
        if (controller.currentStatus == ModuleStatus.disposed) {
          throw ModuleLifecycleException(
            'Dependent module $type was disposed during initialization.',
            moduleType: type,
            state: ModuleStatus.disposed,
          );
        }
      } else if (controller.currentStatus == ModuleStatus.error) {
        throw ModuleLifecycleException(
          'Dependent module $type failed to load: ${controller.lastError}',
          moduleType: type,
          state: ModuleStatus.error,
        );
      }

      return controller;
    });

    // 2. Await all branches concurrently
    final resolvedControllers = await Future.wait(futures);

    return resolvedControllers;
  }
}
