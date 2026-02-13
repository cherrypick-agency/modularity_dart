/// Integration layer between Modularity and the `injectable` code-generation
/// package.
///
/// Provides a [GetItBinder] that manages two separate [GetIt] containers
/// (private and public), a [BinderGetIt] wrapper that resolves through the
/// Modularity binder chain, and a [ModularityInjectableBridge] that connects
/// injectable-generated init functions to the Modularity lifecycle.
///
/// ## Setup
///
/// 1. Use [GetItBinderFactory] when creating your [ModularityRoot]:
///
/// ```dart
/// ModularityRoot(
///   binderFactory: const GetItBinderFactory(),
///   child: const MyApp(),
/// )
/// ```
///
/// 2. In your module, use [ModularityInjectableBridge] to wire registrations:
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
///
/// ## Key Classes
///
/// - [GetItBinder] -- dual-container binder for private/public scopes.
/// - [GetItBinderFactory] -- factory producing [GetItBinder] instances.
/// - [BinderGetIt] -- GetIt wrapper with Modularity binder chain fallback.
/// - [ModularityInjectableBridge] -- connects injectable init functions.
/// - [ModularityExportOnly] -- environment filter for export-only deps.
library modularity_injectable;

export 'src/binder_get_it.dart';
export 'src/get_it_binder.dart';
export 'src/injectable_bridge.dart';
export 'src/modularity_export_env.dart';
