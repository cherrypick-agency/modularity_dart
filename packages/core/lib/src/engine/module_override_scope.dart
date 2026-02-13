import 'package:modularity_contracts/modularity_contracts.dart';

/// Callback that applies dependency overrides to the given [Binder].
///
/// Used by [ModuleOverrideScope] and `ModuleController.overrides` to
/// replace or add registrations after the module's own [Module.binds] runs.
typedef BinderOverride = void Function(Binder binder);

BinderOverride? _composeOverrides(
  BinderOverride? first,
  BinderOverride? second,
) {
  if (first == null) return second;
  if (second == null) return first;
  return (binder) {
    first(binder);
    second(binder);
  };
}

/// Hierarchical tree of [BinderOverride]s that mirrors the module import
/// graph.
///
/// Each node in the tree holds an optional [selfOverrides] callback for the
/// owning module and a [children] map keyed by module [Type] for imported
/// modules. This allows targeted overrides at any depth in the graph
/// without modifying module code.
///
/// ```dart
/// final scope = ModuleOverrideScope(
///   selfOverrides: (binder) {
///     binder.registerSingleton<ApiClient>(MockApiClient());
///   },
///   children: {
///     AuthModule: ModuleOverrideScope(
///       selfOverrides: (binder) {
///         binder.registerSingleton<AuthService>(FakeAuth());
///       },
///     ),
///   },
/// );
///
/// final controller = ModuleController(
///   AppModule(),
///   overrideScopeTree: scope,
/// );
/// ```
///
/// See also:
/// - [BinderOverride] for the callback signature.
/// - `ModuleController` for how the scope is applied during initialization.
class ModuleOverrideScope {
  /// Creates a scope with optional [selfOverrides] and [children] map.
  const ModuleOverrideScope({this.selfOverrides, this.children = const {}});

  /// Override callback applied to the owning module's [Binder], or `null` if
  /// no overrides are needed at this level.
  final BinderOverride? selfOverrides;

  /// Per-module-type override scopes for imported (child) modules.
  final Map<Type, ModuleOverrideScope> children;

  /// Returns the override scope for the imported module of the given [type],
  /// or `null` if no overrides exist for that module.
  ModuleOverrideScope? childFor(Type type) => children[type];

  /// Returns a new scope whose [selfOverrides] is the composition of the
  /// current callback followed by [override].
  ModuleOverrideScope withAdditionalOverride(BinderOverride? override) {
    return ModuleOverrideScope(
      selfOverrides: _composeOverrides(selfOverrides, override),
      children: children,
    );
  }

  /// Deeply merges this scope with [other].
  ///
  /// Override callbacks are composed in order: **this** first, then [other].
  /// Child maps are merged recursively.
  ModuleOverrideScope merge(ModuleOverrideScope? other) {
    if (other == null) return this;
    final mergedChildren = <Type, ModuleOverrideScope>{}..addAll(children);
    other.children.forEach((key, value) {
      final existing = mergedChildren[key];
      mergedChildren[key] = existing == null ? value : existing.merge(value);
    });

    return ModuleOverrideScope(
      selfOverrides: _composeOverrides(selfOverrides, other.selfOverrides),
      children: mergedChildren,
    );
  }
}
