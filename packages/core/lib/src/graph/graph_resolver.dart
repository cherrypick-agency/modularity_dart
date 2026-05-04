import 'dart:async';
import 'package:modularity_contracts/modularity_contracts.dart';
import '../engine/module_controller.dart';
import '../engine/module_override_scope.dart';
import 'module_graph_node_key.dart';
import 'module_registry_key.dart';

/// Resolves the module import graph and initializes dependencies
/// concurrently.
///
/// For each import declared by a [Module], the resolver:
/// 1. Checks for circular dependencies using a per-branch graph stack.
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
    Set<ModuleGraphNodeKey>? graphResolutionStack,
    List<ModuleInterceptor> interceptors = const [],
    ModuleOverrideScope? overrideScope,
  }) async {
    final seedStack =
        graphResolutionStack ??
        _legacyTypeStackToGraphStack(resolutionStack) ??
        const <ModuleGraphNodeKey>{};
    final currentStack = {...seedStack, ModuleGraphNodeKey.fromModule(module)};

    // 1. Prepare all tasks (Futures) and launch them concurrently
    final futures = module.imports.map((importModule) async {
      final type = importModule.runtimeType;
      final graphNode = ModuleGraphNodeKey.fromModule(importModule);

      // Check Circular Dependency (Immediate Fail-Fast)
      if (currentStack.contains(graphNode)) {
        throw CircularDependencyException(
          'Circular dependency detected: ${currentStack.join(' -> ')} -> $graphNode',
          dependencyChain: [
            ...currentStack.map((node) => node.moduleType),
            type,
          ],
        );
      }

      // --- CRITICAL SECTION START (Synchronous) ---
      // Important: Getting or creating the controller must be atomic
      // so that concurrent branches don't create duplicates.
      // In Dart this block won't be preempted as long as there's no await.
      final childScope = overrideScope?.childFor(type);
      final registryKey = ModuleRegistryKey(
        moduleType: type,
        moduleIdentity: importModule.identityKey,
        overrideScope: childScope,
      );
      ModuleController? controller = registry[registryKey];

      if (controller?.currentStatus == ModuleStatus.disposed) {
        registry.remove(registryKey);
        controller = null;
      }

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
      final newStack = {...currentStack, graphNode};

      // Now it's safe to await (yield execution). ModuleController coalesces
      // concurrent initialize calls, so a loading import can be awaited without
      // relying on status stream timing.
      if (controller.currentStatus == ModuleStatus.initial ||
          controller.currentStatus == ModuleStatus.loading) {
        await controller.initialize(registry, graphResolutionStack: newStack);
      }

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

      return controller;
    });

    // 2. Await all branches concurrently
    final resolvedControllers = await Future.wait(futures);

    return resolvedControllers;
  }

  Set<ModuleGraphNodeKey>? _legacyTypeStackToGraphStack(
    Set<Type>? resolutionStack,
  ) {
    if (resolutionStack == null) return null;
    return {
      for (final type in resolutionStack) ModuleGraphNodeKey(moduleType: type),
    };
  }
}
