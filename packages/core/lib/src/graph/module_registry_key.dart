import '../engine/module_override_scope.dart';

/// Composite key used in the global module registry to differentiate
/// [ModuleController] instances by both their runtime [Type] and
/// [ModuleOverrideScope].
///
/// Two keys are equal when they have the same [moduleType] and point to
/// the **identical** [overrideScope] object (identity comparison, not deep
/// equality). This ensures that modules with different override trees
/// get separate controllers.
///
/// See also:
/// - `GraphResolver` which uses this key to deduplicate controllers.
class ModuleRegistryKey {
  /// Creates a registry key for the given [moduleType] and optional
  /// [overrideScope].
  const ModuleRegistryKey({required this.moduleType, this.overrideScope});

  /// The runtime [Type] of the [Module] this key identifies.
  final Type moduleType;

  /// The [ModuleOverrideScope] associated with this particular controller
  /// instance, or `null` when no overrides are applied.
  final ModuleOverrideScope? overrideScope;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModuleRegistryKey &&
        other.moduleType == moduleType &&
        identical(other.overrideScope, overrideScope);
  }

  @override
  int get hashCode => Object.hash(moduleType, overrideScope);
}
