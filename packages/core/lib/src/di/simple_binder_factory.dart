import 'package:modularity_contracts/modularity_contracts.dart';
import 'simple_binder.dart';

/// Default [BinderFactory] that produces [SimpleBinder] instances.
///
/// Used automatically by `ModuleController` when no custom factory is
/// supplied. Provides a zero-dependency, pure-Dart binder for every module.
///
/// See also:
/// - [SimpleBinder] for the binder implementation.
/// - [BinderFactory] for the factory contract.
class SimpleBinderFactory implements BinderFactory {
  /// Creates a new [SimpleBinder], optionally chaining it to a [parent] scope.
  @override
  Binder create([Binder? parent]) {
    return SimpleBinder(parent: parent);
  }
}
