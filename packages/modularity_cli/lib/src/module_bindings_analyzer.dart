import 'package:modularity_contracts/modularity_contracts.dart';

import 'recording_binder.dart';

/// Immutable snapshot of a [Module]'s dependency registrations.
///
/// Produced by [ModuleBindingsAnalyzer] after introspecting a module's
/// `binds`, `exports`, and `expects` declarations.
class ModuleBindingsSnapshot {
  /// Create a snapshot for the given [moduleType].
  ModuleBindingsSnapshot({
    required this.moduleType,
    required this.privateDependencies,
    required this.publicDependencies,
    required this.expects,
    required this.warnings,
  });

  /// The runtime type of the analyzed [Module].
  final Type moduleType;

  /// Dependencies registered in the private scope via `binds`.
  final List<DependencyRecord> privateDependencies;

  /// Dependencies exported via the public scope through `exports`.
  final List<DependencyRecord> publicDependencies;

  /// Types the module declares as required from ancestor scopes.
  final List<Type> expects;

  /// Warnings collected during analysis (e.g. phase failures).
  final List<String> warnings;

  /// Return `true` if the module registered at least one dependency.
  bool get hasBindings =>
      privateDependencies.isNotEmpty || publicDependencies.isNotEmpty;

  /// Return `true` if the module declares at least one expected type.
  bool get hasExpects => expects.isNotEmpty;
}

/// Analyze a [Module] tree and produce [ModuleBindingsSnapshot] for each node.
///
/// Uses a [RecordingBinder] to introspect registrations without constructing
/// real dependencies. Results are cached by module runtime type.
class ModuleBindingsAnalyzer {
  final Map<Type, ModuleBindingsSnapshot> _cache = {};
  final Map<Type, RecordingBinder> _binderCache = {};

  /// Analyze the given [module] and return a snapshot of its bindings.
  ///
  /// Throws [CircularDependencyException] if a cycle is detected.
  ModuleBindingsSnapshot analyze(Module module) {
    return _analyze(module, <Type>{});
  }

  ModuleBindingsSnapshot _analyze(Module module, Set<Type> stack) {
    final type = module.runtimeType;

    if (_cache.containsKey(type)) {
      return _cache[type]!;
    }

    if (stack.contains(type)) {
      throw CircularDependencyException(
        'Circular module imports detected: ${[...stack, type].map((t) => t.toString()).join(' -> ')}',
        dependencyChain: [...stack, type],
      );
    }

    final imports = module.imports;
    final newStack = {...stack, type};

    final importBinders = <RecordingBinder>[];
    for (final importModule in imports) {
      final snapshot = _analyze(importModule, newStack);
      final binder = _binderCache[snapshot.moduleType];
      if (binder != null) {
        importBinders.add(binder);
      }
    }

    final binder = RecordingBinder(imports: importBinders);
    _binderCache[type] = binder;
    final warnings = <String>[];

    void runPhase(String phase, void Function() action) {
      try {
        action();
      } catch (error) {
        final message =
            'GraphVisualizer: $type $phase() analysis failed: $error';
        warnings.add(message);
        print(message);
      }
    }

    runPhase('binds', () => module.binds(binder));

    binder.enableExportMode();
    runPhase('exports', () => module.exports(binder));
    binder
      ..disableExportMode()
      ..sealPublicScope();

    final snapshot = ModuleBindingsSnapshot(
      moduleType: type,
      privateDependencies: binder.privateDependencies,
      publicDependencies: binder.publicDependencies,
      expects: List.unmodifiable(module.expects),
      warnings: List.unmodifiable(warnings),
    );

    _cache[type] = snapshot;
    return snapshot;
  }
}
