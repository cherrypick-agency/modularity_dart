import 'package:modularity_contracts/modularity_contracts.dart';

/// Proxy [Binder] implementation that records all registrations and
/// resolutions, useful for testing module behavior.
///
/// Wraps a real [Binder] delegate and tracks every `registerLazySingleton`,
/// `registerFactory`, `registerSingleton`, `get`, and `tryGet` call. After
/// module initialization, use inspection methods to assert registration
/// behavior:
///
/// ```dart
/// await testModule(MyModule(), (module, binder) {
///   expect(binder.hasSingleton<MyService>(), isTrue);
///   expect(binder.hasFactory<MyRepo>(), isTrue);
///   expect(binder.wasResolved<MyService>(), isFalse);
/// });
/// ```
///
/// Implements [ExportableBinder] so it can be used in place of any binder
/// in tests that exercise export-mode registrations. When the underlying
/// delegate is itself an [ExportableBinder], calls are forwarded; otherwise
/// the export-mode methods operate on local tracking state only.
///
/// See also:
/// - [testModule] which creates and uses this binder automatically.
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

  /// Unmodifiable list of types registered via [registerLazySingleton].
  List<Type> get registeredSingletons =>
      List.unmodifiable(_registeredSingletons);

  /// Unmodifiable list of types registered as eager singletons.
  List<Type> get registeredEagerSingletons =>
      List.unmodifiable(_registeredEagerSingletons);

  /// Unmodifiable list of types registered via [registerFactory].
  List<Type> get registeredFactories => List.unmodifiable(_registeredFactories);

  /// Unmodifiable list of types registered via [registerSingleton].
  List<Type> get registeredInstances => List.unmodifiable(_registeredInstances);

  /// Unmodifiable list of types that were resolved via [get] or [tryGet].
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

  /// Returns `true` if [T] was registered via [registerLazySingleton].
  bool hasSingleton<T>() => _registeredSingletons.contains(T);

  /// Returns `true` if [T] was registered via [registerFactory].
  bool hasFactory<T>() => _registeredFactories.contains(T);

  /// Returns `true` if [T] was registered via [registerSingleton].
  bool hasInstance<T>() => _registeredInstances.contains(T);

  /// Returns `true` if [T] was resolved via [get] or [tryGet].
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
