import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:modularity_contracts/modularity_contracts.dart' as contracts;

import 'binder_get_it.dart';
import 'get_it_binder.dart';
import 'modularity_export_env.dart';

/// Signature of a generated injectable init function.
typedef InjectableInitFn =
    GetIt Function(
      GetIt getIt, {
      String? environment,
      EnvironmentFilter? environmentFilter,
    });

/// Helper that wires injectable-generated functions into the Modularity lifecycle.
class ModularityInjectableBridge {
  const ModularityInjectableBridge._();

  /// Registers all private dependencies inside Module.binds.
  static void configureInternal(
    contracts.Binder binder,
    InjectableInitFn initFn,
  ) {
    final scopedBinder = _expectGetItBinder(binder);
    initFn(
      BinderGetIt(primary: scopedBinder.internalContainer, binder: binder),
    );
  }

  /// Registers only export-marked dependencies inside Module.exports.
  static void configureExports(
    contracts.Binder binder,
    InjectableInitFn initFn,
  ) {
    final scopedBinder = _expectGetItBinder(binder);
    initFn(
      BinderGetIt(primary: scopedBinder.publicContainer, binder: binder),
      environmentFilter: const ModularityExportOnly(),
    );
  }

  static GetItBinder _expectGetItBinder(contracts.Binder binder) {
    if (binder is GetItBinder) return binder;
    throw contracts.ModuleConfigurationException(
      'Injectable integration requires GetItBinder. '
      'Provide GetItBinderFactory to ModularityRoot or ModuleController.',
    );
  }
}
