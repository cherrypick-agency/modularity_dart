import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

import 'get_it_binder.dart';
import 'modularity_export_env.dart';

/// Signature of a generated injectable init function.
typedef InjectableInitFn = GetIt Function(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
});

/// Helper that wires injectable-generated functions into the Modularity lifecycle.
class ModularityInjectableBridge {
  const ModularityInjectableBridge._();

  /// Registers all private dependencies inside [Module.binds].
  static void configureInternal(Binder binder, InjectableInitFn initFn) {
    final scopedBinder = _expectGetItBinder(binder);
    initFn(scopedBinder.internalContainer);
  }

  /// Registers only export-marked dependencies inside [Module.exports].
  static void configureExports(Binder binder, InjectableInitFn initFn) {
    final scopedBinder = _expectGetItBinder(binder);
    initFn(
      scopedBinder.publicContainer,
      environmentFilter: const ModularityExportOnly(),
    );
  }

  static GetItBinder _expectGetItBinder(Binder binder) {
    if (binder is GetItBinder) return binder;
    throw StateError(
      'Injectable integration requires GetItBinder. '
      'Provide GetItBinderFactory to ModularityRoot or ModuleController.',
    );
  }
}
