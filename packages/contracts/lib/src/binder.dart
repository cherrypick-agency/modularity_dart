/// Defines the strategy for handling duplicate dependency registrations.
enum RegistrationStrategy {
  /// Re-registration replaces the previous value (default).
  replace,

  /// Re-registration preserves existing singletons/instances and
  /// only updates factories.
  preserveExisting,
}

/// Interface for registering dependencies.
/// Abstracts the concrete DI implementation (be it GetIt, a map, or anything else).
abstract class Binder {
  /// Alias for [registerLazySingleton].
  /// Registers a singleton. Created once on first request (lazy).
  @Deprecated('Use registerLazySingleton instead')
  void singleton<T extends Object>(T Function() factory);

  /// Registers a lazy singleton.
  /// Created once on first request.
  /// Same as [singleton] in Binder, renamed to match the GetIt API.
  void registerLazySingleton<T extends Object>(T Function() factory);

  /// Alias for [registerFactory].
  /// Registers a factory. Creates a new instance on every request.
  @Deprecated('Use registerFactory instead')
  void factory<T extends Object>(T Function() factory);

  /// Registers a factory.
  /// Creates a new instance on every request.
  /// Same as [factory] in Binder, renamed to match the GetIt API.
  void registerFactory<T extends Object>(T Function() factory);

  /// Registers an already-created instance (Eager Singleton).
  /// Replaces the legacy [instance] and [eagerSingleton] methods.
  void registerSingleton<T extends Object>(T instance);

  /// Retrieves a dependency of type [T].
  /// [moduleId] is an optional module identifier for scoping.
  T get<T extends Object>();

  /// Attempts to retrieve a dependency, returns null if not found.
  T? tryGet<T extends Object>();

  /// Retrieves a dependency from the parent scope (Explicit Parent Lookup).
  T parent<T extends Object>();

  /// Attempts to retrieve a dependency from the parent scope.
  T? tryParent<T extends Object>();

  /// Adds external binders (imports) to search for dependencies.
  void addImports(List<Binder> binders);

  /// Checks whether a dependency of the given type exists (including parents and imports).
  bool contains(Type type);
}

/// Extended interface for Binder that supports exporting dependencies.
abstract class ExportableBinder implements Binder {
  /// Enables export mode (registrations go to the public scope).
  void enableExportMode();

  /// Disables export mode (registrations go to the private scope).
  void disableExportMode();

  /// Attempts to retrieve a dependency ONLY from the public scope.
  T? tryGetPublic<T extends Object>();

  /// Checks whether a public dependency of the given type exists.
  bool containsPublic(Type type);

  /// Marks the public scope as sealed after exports are complete.
  /// After this call, new export-mode registrations are rejected until
  /// [resetPublicScope] explicitly reopens it (e.g. for hot reload).
  void sealPublicScope();

  /// Resets the public scope seal flag. Needed for hot reload
  /// when factories need to be updated without creating a new Binder.
  void resetPublicScope();

  /// Flag indicating whether export mode is currently active.
  bool get isExportModeEnabled;

  /// Flag indicating whether the public scope has been sealed.
  bool get isPublicScopeSealed;
}

/// Contract for a [Binder] that supports explicit disposal of resources.
///
/// Implementations should release all internal registrations when [dispose]
/// is called. The [ModuleController] checks for this interface during its
/// own disposal to ensure binder resources are freed regardless of the
/// concrete binder type.
abstract class DisposableBinder implements Binder {
  /// Release all resources held by this binder.
  Future<void> dispose();
}

/// Additional contract for a Binder that can switch its registration
/// strategy at runtime (e.g. for hot reload).
abstract class RegistrationAwareBinder implements Binder {
  /// The current registration strategy.
  RegistrationStrategy get registrationStrategy;

  /// Executes [body] with the given [strategy], automatically restoring
  /// the previous strategy when [body] completes.
  T runWithStrategy<T>(RegistrationStrategy strategy, T Function() body);
}
