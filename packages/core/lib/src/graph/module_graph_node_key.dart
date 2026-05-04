import 'package:modularity_contracts/modularity_contracts.dart';

/// Identity of a module node inside the import graph.
///
/// Unlike [ModuleRegistryKey], this key intentionally ignores override scope.
/// Override scope changes dependency bindings, but it does not make an
/// `A -> B -> A` import cycle valid. [Module.identityKey] is included so
/// same-type modules with different runtime identity can form a valid chain.
class ModuleGraphNodeKey {
  /// Creates a graph node key.
  const ModuleGraphNodeKey({required this.moduleType, this.moduleIdentity});

  /// Creates a graph node key from a [Module] instance.
  factory ModuleGraphNodeKey.fromModule(Module module) {
    return ModuleGraphNodeKey(
      moduleType: module.runtimeType,
      moduleIdentity: module.identityKey,
    );
  }

  /// Runtime type of the module.
  final Type moduleType;

  /// Optional identity from [Module.identityKey].
  final Object? moduleIdentity;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModuleGraphNodeKey &&
        other.moduleType == moduleType &&
        other.moduleIdentity == moduleIdentity;
  }

  @override
  int get hashCode => Object.hash(moduleType, moduleIdentity);

  @override
  String toString() {
    if (moduleIdentity == null) {
      return moduleType.toString();
    }
    return '$moduleType#$moduleIdentity';
  }
}
