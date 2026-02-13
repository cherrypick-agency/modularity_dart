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

/// Helper that wires injectable-generated init functions into the Modularity
/// module lifecycle.
///
/// Call [configureInternal] from `Module.binds` to register private
/// dependencies, and [configureExports] from `Module.exports` to register
/// only those dependencies annotated with [modularityExportEnv].
///
/// Requires a [GetItBinder] as the active binder (provided by
/// [GetItBinderFactory]).
///
/// ```dart
/// class AuthModule extends Module {
///   @override
///   void binds(Binder binder) {
///     ModularityInjectableBridge.configureInternal(binder, configureDependencies);
///   }
///
///   @override
///   void exports(Binder binder) {
///     ModularityInjectableBridge.configureExports(binder, configureDependencies);
///   }
/// }
/// ```
class ModularityInjectableBridge {
  const ModularityInjectableBridge._();

  /// Registers all private dependencies inside `Module.binds`.
  ///
  /// Wraps the [binder]'s internal container with [BinderGetIt] so
  /// injectable-generated factories can resolve cross-module dependencies
  /// through the Modularity binder chain.
  static void configureInternal(
    contracts.Binder binder,
    InjectableInitFn initFn,
  ) {
    final scopedBinder = _expectGetItBinder(binder);
    initFn(
      BinderGetIt(primary: scopedBinder.internalContainer, binder: binder),
    );
  }

  /// Registers only export-marked dependencies inside `Module.exports`.
  ///
  /// Uses [ModularityExportOnly] as the environment filter, so only
  /// dependencies annotated with `@Environment(modularityExportEnvName)` or
  /// `@modularityExportEnv` are processed.
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
