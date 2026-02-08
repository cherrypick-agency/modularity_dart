import 'package:modularity_contracts/modularity_contracts.dart';

/// A Proxy Binder implementation that records all interactions.
/// Useful for testing module behavior.
///
/// Implements [ExportableBinder] so it can be used in place of any binder
/// in tests that exercise export-mode registrations. When the underlying
/// delegate is itself an [ExportableBinder], calls are forwarded; otherwise
/// the export-mode methods operate on local tracking state only.
class TestBinder implements ExportableBinder {
  /// Create a test binder wrapping the given [_delegate].
  TestBinder(this._delegate);
  final Binder _delegate;

  final List<Type> _registeredSingletons = [];
  final List<Type> _registeredEagerSingletons = [];
  final List<Type> _registeredFactories = [];
  final List<Type> _registeredInstances = [];
  final List<Type> _resolvedTypes = [];

  bool _isExportMode = false;
  bool _publicSealed = false;

  /// List of types registered as Singletons.
  List<Type> get registeredSingletons =>
      List.unmodifiable(_registeredSingletons);

  /// List of types registered as Eager Singletons.
  List<Type> get registeredEagerSingletons =>
      List.unmodifiable(_registeredEagerSingletons);

  /// List of types registered as Factories.
  List<Type> get registeredFactories => List.unmodifiable(_registeredFactories);

  /// List of types registered as Instances.
  List<Type> get registeredInstances => List.unmodifiable(_registeredInstances);

  /// List of types that were resolved (get/tryGet).
  List<Type> get resolvedTypes => List.unmodifiable(_resolvedTypes);

  @override
  void registerLazySingleton<T extends Object>(T Function() factory) {
    _registeredSingletons.add(T);
    _delegate.registerLazySingleton<T>(factory);
  }

  @override
  void registerFactory<T extends Object>(T Function() factory) {
    _registeredFactories.add(T);
    _delegate.registerFactory<T>(factory);
  }

  @override
  void registerSingleton<T extends Object>(T instance) {
    _registeredInstances.add(T);
    _delegate.registerSingleton<T>(instance);
  }

  @Deprecated('Use registerLazySingleton instead')
  @override
  void singleton<T extends Object>(T Function() factory) =>
      registerLazySingleton(factory);

  @Deprecated('Use registerFactory instead')
  @override
  void factory<T extends Object>(T Function() factory) =>
      registerFactory(factory);

  @override
  T get<T extends Object>() {
    _resolvedTypes.add(T);
    return _delegate.get<T>();
  }

  @override
  T? tryGet<T extends Object>() {
    _resolvedTypes.add(T);
    return _delegate.tryGet<T>();
  }

  @override
  T parent<T extends Object>() {
    return _delegate.parent<T>();
  }

  @override
  T? tryParent<T extends Object>() {
    return _delegate.tryParent<T>();
  }

  @override
  void addImports(List<Binder> binders) {
    _delegate.addImports(binders);
  }

  @override
  bool contains(Type type) {
    return _delegate.contains(type);
  }

  /// Checks if a type was registered as Singleton.
  bool hasSingleton<T>() => _registeredSingletons.contains(T);

  /// Checks if a type was registered as Factory.
  bool hasFactory<T>() => _registeredFactories.contains(T);

  /// Checks if a type was registered as Instance.
  bool hasInstance<T>() => _registeredInstances.contains(T);

  /// Checks if a type was resolved.
  bool wasResolved<T>() => _resolvedTypes.contains(T);

  // -- ExportableBinder implementation --

  @override
  void enableExportMode() {
    _isExportMode = true;
    final delegate = _delegate;
    if (delegate is ExportableBinder) {
      delegate.enableExportMode();
    }
  }

  @override
  void disableExportMode() {
    _isExportMode = false;
    final delegate = _delegate;
    if (delegate is ExportableBinder) {
      delegate.disableExportMode();
    }
  }

  @override
  bool get isExportModeEnabled => _isExportMode;

  @override
  T? tryGetPublic<T extends Object>() {
    final delegate = _delegate;
    if (delegate is ExportableBinder) {
      return delegate.tryGetPublic<T>();
    }
    return null;
  }

  @override
  bool containsPublic(Type type) {
    final delegate = _delegate;
    if (delegate is ExportableBinder) {
      return delegate.containsPublic(type);
    }
    return false;
  }

  @override
  void sealPublicScope() {
    _publicSealed = true;
    final delegate = _delegate;
    if (delegate is ExportableBinder) {
      delegate.sealPublicScope();
    }
  }

  @override
  void resetPublicScope() {
    _publicSealed = false;
    final delegate = _delegate;
    if (delegate is ExportableBinder) {
      delegate.resetPublicScope();
    }
  }

  @override
  bool get isPublicScopeSealed => _publicSealed;
}
