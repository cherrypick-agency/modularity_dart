import 'package:modularity_contracts/modularity_contracts.dart';
import 'get_it_binder.dart';

/// [BinderFactory] that produces standalone [GetItBinder] instances.
///
/// Set [useGlobalInstance] to `true` to share the global [GetIt.instance]
/// across all created binders instead of creating isolated containers.
///
/// ```dart
/// // Isolated containers (default)
/// const factory = GetItBinderFactory();
///
/// // Shared global GetIt instance
/// const factory = GetItBinderFactory(useGlobalInstance: true);
/// ```
///
/// See also:
/// - [GetItBinder] for the binder implementation details.
class GetItBinderFactory implements BinderFactory {
  /// Create a factory, optionally enabling [useGlobalInstance].
  const GetItBinderFactory({this.useGlobalInstance = false});

  /// Whether created binders should use the global [GetIt] singleton.
  final bool useGlobalInstance;

  @override
  Binder create([Binder? parent]) {
    return GetItBinder(parent, useGlobalInstance);
  }
}
