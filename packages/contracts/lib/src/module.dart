import 'dart:async';
import 'binder.dart';
import 'configurable.dart';

/// Lifecycle statuses of a module.
///
/// A module progresses through these states during its lifetime:
///
/// ```
/// initial -> loading -> loaded -> disposed
///                   \-> error
/// ```
enum ModuleStatus {
  /// Module has been created but initialization has not started.
  initial,

  /// Module is currently initializing ([Module.onInit] is running).
  loading,

  /// Module has been successfully initialized and is ready to use.
  loaded,

  /// An error occurred during initialization.
  error,

  /// Module has been disposed and should not be used.
  disposed,
}

/// Base contract for a module in the Modularity framework.
///
/// A module is an isolated unit of functionality with its own dependency
/// registrations and lifecycle. Override [binds] to register private
/// dependencies and [exports] to expose public ones.
///
/// ```dart
/// class NetworkModule extends Module {
///   @override
///   List<Module> get imports => [LoggingModule()];
///
///   @override
///   void binds(Binder i) {
///     i.registerLazySingleton<HttpClient>(() => HttpClient());
///   }
///
///   @override
///   void exports(Binder i) {
///     i.registerFactory<ApiClient>(
///       () => ApiClient(i.get<HttpClient>()),
///     );
///   }
///
///   @override
///   Future<void> onInit() async {
///     // Perform async setup after all dependencies are registered.
///   }
/// }
/// ```
///
/// See also:
/// - [Binder] for the dependency registration API.
/// - [Configurable] for modules that accept runtime configuration.
/// - [ModuleStatus] for the lifecycle state machine.
abstract class Module {
  /// Modules that this module depends on.
  ///
  /// Imports are resolved and initialized **before** this module's [binds]
  /// is called. Their exported dependencies become available through the
  /// binder's import chain.
  List<Module> get imports => [];

  /// Structural sub-features that compose this module.
  ///
  /// Used for **static analysis and visualization only** (e.g. by
  /// `modularity_cli`). Submodules listed here should implement
  /// [Configurable] for runtime parameters instead of relying on
  /// constructor arguments.
  List<Module> get submodules => [];

  /// Types that the parent scope **must** provide.
  ///
  /// Checked at startup before [binds] runs. If any listed type is missing
  /// from the parent scope or imports, initialization fails with
  /// [ModuleConfigurationException].
  List<Type> get expects => [];

  /// Registers dependencies available **only** within this module.
  ///
  /// Place internal implementations, data sources, and mappers here.
  /// These dependencies are invisible to modules that import this one.
  void binds(Binder i);

  /// Registers dependencies that this module **exports** to importers.
  ///
  /// Only public interfaces and facades should be registered here.
  /// The binder is in export mode, so registrations go to the public scope.
  void exports(Binder i) {}

  /// Asynchronous initialization hook.
  ///
  /// Called after all [imports] have reached [ModuleStatus.loaded] and
  /// after [binds] and [exports] have been executed. Use this to perform
  /// async setup such as opening database connections or pre-loading caches.
  Future<void> onInit() async {}

  /// Resource cleanup hook.
  ///
  /// Called when the module is being disposed. Release connections, cancel
  /// subscriptions, or perform other cleanup here.
  void onDispose() {}

  /// Hot-reload hook.
  ///
  /// Called during Flutter hot reload to allow updating factory closures
  /// without losing singleton state. The binder runs under
  /// [RegistrationStrategy.preserveExisting] when this hook is invoked.
  void hotReload(Binder i) {}
}
