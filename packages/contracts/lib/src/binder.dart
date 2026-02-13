/// Defines the strategy for handling duplicate dependency registrations.
///
/// Used by [RegistrationAwareBinder] to control what happens when a type
/// is registered more than once (e.g. during hot reload).
enum RegistrationStrategy {
  /// Re-registration replaces the previous value (default).
  replace,

  /// Re-registration preserves existing singletons/instances and
  /// only updates factories.
  ///
  /// Useful during hot reload: singleton state is kept while factory
  /// closures are refreshed to pick up code changes.
  preserveExisting,
}

/// Core interface for registering and resolving dependencies.
///
/// [Binder] abstracts the concrete DI container (be it GetIt, a simple map,
/// or any other implementation) behind a uniform API used by [Module.binds]
/// and [Module.exports].
///
/// Dependency resolution follows the order: **Local -> Imports -> Parent**.
///
/// ```dart
/// class NetworkModule extends Module {
///   @override
///   void binds(Binder i) {
///     i.registerLazySingleton<HttpClient>(() => HttpClient());
///     i.registerFactory<ApiService>(() => ApiService(i.get<HttpClient>()));
///   }
/// }
/// ```
///
/// See also:
/// - [ExportableBinder] for modules that expose dependencies publicly.
/// - [DisposableBinder] for binders that support resource cleanup.
/// - [RegistrationAwareBinder] for hot-reload-aware binders.
abstract class Binder {
  /// Registers a lazy singleton of type [T].
  ///
  /// The [factory] closure is called **once** on the first [get] call;
  /// subsequent calls return the cached instance.
  void registerLazySingleton<T extends Object>(T Function() factory);

  /// Registers a factory for type [T].
  ///
  /// The [factory] closure is called on **every** [get] call, producing
  /// a new instance each time.
  void registerFactory<T extends Object>(T Function() factory);

  /// Registers an already-created [instance] as an eager singleton of type [T].
  void registerSingleton<T extends Object>(T instance);

  /// Resolves a dependency of type [T].
  ///
  /// Throws [DependencyNotFoundException] if the type is not registered.
  T get<T extends Object>();

  /// Attempts to resolve a dependency of type [T].
  ///
  /// Returns `null` instead of throwing when the type is not found.
  T? tryGet<T extends Object>();

  /// Resolves a dependency of type [T] from the parent scope.
  ///
  /// Throws [DependencyNotFoundException] if the parent scope does not
  /// contain the requested type.
  T parent<T extends Object>();

  /// Attempts to resolve a dependency of type [T] from the parent scope.
  ///
  /// Returns `null` when the parent scope does not contain the type.
  T? tryParent<T extends Object>();

  /// Appends [binders] to the list of imported scopes searched during
  /// dependency resolution.
  void addImports(List<Binder> binders);

  /// Returns `true` if [type] is registered in any reachable scope
  /// (local, imports, or parent chain).
  bool contains(Type type);
}

/// Extended [Binder] that separates registrations into private and public
/// (exported) scopes.
///
/// Dependencies registered while [isExportModeEnabled] is `true` go to the
/// public scope and become visible to modules that import this one.
/// Dependencies registered in the default (private) mode are only accessible
/// within the owning module.
///
/// See also:
/// - [Binder] for the base registration/resolution API.
/// - [Module.exports] where export mode is used.
abstract class ExportableBinder implements Binder {
  /// Enables export mode so that subsequent registrations go to the
  /// public scope.
  void enableExportMode();

  /// Disables export mode so that subsequent registrations go to the
  /// private scope.
  void disableExportMode();

  /// Resolves a dependency of type [T] from the **public scope only**.
  ///
  /// Used internally when resolving imports between modules.
  T? tryGetPublic<T extends Object>();

  /// Returns `true` if [type] is registered in the public (exported) scope.
  bool containsPublic(Type type);

  /// Seals the public scope so that further export-mode registrations
  /// throw [ModuleConfigurationException].
  ///
  /// Call [resetPublicScope] to reopen it (e.g. for hot reload).
  void sealPublicScope();

  /// Reopens a sealed public scope, allowing new export-mode registrations.
  ///
  /// Typically called during hot reload to update factory closures.
  void resetPublicScope();

  /// Whether export mode is currently active.
  bool get isExportModeEnabled;

  /// Whether the public scope has been sealed.
  bool get isPublicScopeSealed;
}

/// Contract for a [Binder] that supports explicit disposal of resources.
///
/// Implementations should release all internal registrations when [dispose]
/// is called. The `ModuleController` checks for this interface during its
/// own disposal to ensure binder resources are freed regardless of the
/// concrete binder type.
///
/// See also:
/// - [Binder] for the base registration/resolution API.
abstract class DisposableBinder implements Binder {
  /// Releases all resources held by this binder, clearing every
  /// registration in both private and public scopes.
  Future<void> dispose();
}

/// Contract for a [Binder] that can switch its [RegistrationStrategy]
/// at runtime.
///
/// This is primarily used during hot reload: the engine temporarily
/// switches to [RegistrationStrategy.preserveExisting] so that
/// singleton state survives while factory closures are refreshed.
///
/// See also:
/// - [RegistrationStrategy] for the available strategies.
/// - [Binder] for the base registration/resolution API.
abstract class RegistrationAwareBinder implements Binder {
  /// The currently active [RegistrationStrategy].
  RegistrationStrategy get registrationStrategy;

  /// Executes [body] under the given [strategy], automatically restoring
  /// the previous strategy when [body] completes (even if it throws).
  T runWithStrategy<T>(RegistrationStrategy strategy, T Function() body);
}
