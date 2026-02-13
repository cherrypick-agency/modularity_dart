import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

/// Standalone [Binder] implementation backed by a single scoped [GetIt]
/// instance, with [RegistrationAwareBinder] support for strategy switching.
///
/// Uses one [GetIt] container for both private and exported registrations,
/// tracking exported types via an internal set.
///
/// ## Registration Strategies
///
/// Supports [RegistrationAwareBinder] which enables switching between
/// `replace` and `preserveExisting` strategies at runtime. This is useful
/// for hot reload, where existing registrations should be preserved while
/// factory delegates are updated.
///
/// ## Resolution Order
///
/// When [get] or [tryGet] is called, lookup proceeds as:
/// 1. Local [GetIt] container.
/// 2. Imported binders (public exports only).
/// 3. Parent binder (if any).
///
/// **Note:** A different class also named `GetItBinder` exists in the
/// `modularity_injectable` package. That variant manages two separate [GetIt]
/// instances (private + public) and is designed for `injectable` code-gen.
///
/// See also:
/// - [GetItBinderFactory] which produces these binders.
class GetItBinder
    implements ExportableBinder, RegistrationAwareBinder, DisposableBinder {
  /// Create a binder optionally linked to a [_parent] scope.
  ///
  /// When [_useGlobalInstance] is `true`, the global [GetIt.instance] is
  /// used instead of a fresh isolated container.
  GetItBinder([this._parent, this._useGlobalInstance = false]) {
    _getIt = _useGlobalInstance ? GetIt.instance : GetIt.asNewInstance();
  }
  late final GetIt _getIt;
  final bool _useGlobalInstance;
  final List<FutureOr<void> Function()> _cleanupCallbacks = [];

  final Binder? _parent;
  final List<Binder> _imports = [];

  final Set<Type> _exportedTypes = {};
  bool _isExportMode = false;
  bool _publicSealed = false;
  final List<RegistrationStrategy> _strategyStack = [
    RegistrationStrategy.replace,
  ];
  final Map<Type, Object Function()> _factoryDelegates = {};
  final Map<Type, Object Function()> _lazySingletonDelegates = {};

  @override
  void enableExportMode() => _isExportMode = true;

  @override
  void disableExportMode() => _isExportMode = false;

  @override
  bool get isExportModeEnabled => _isExportMode;

  @override
  bool get isPublicScopeSealed => _publicSealed;

  @override
  void sealPublicScope() => _publicSealed = true;

  @override
  void resetPublicScope() {
    _publicSealed = false;
  }

  @override
  void addImports(List<Binder> binders) {
    _imports.addAll(binders);
  }

  @override
  bool contains(Type type) {
    // 1. Local
    if (_getIt.isRegistered(type: type)) return true;

    // 2. Imports (only check public exports)
    for (final imported in _imports) {
      if (imported is ExportableBinder) {
        if (imported.containsPublic(type)) return true;
      } else {
        if (imported.contains(type)) return true;
      }
    }

    // 3. Parent
    if (_parent?.contains(type) ?? false) return true;

    return false;
  }

  @override
  bool containsPublic(Type type) {
    return _exportedTypes.contains(type) && _getIt.isRegistered(type: type);
  }

  @override
  void registerLazySingleton<T extends Object>(T Function() factory) {
    _assertCanExport();
    final isPreserve =
        registrationStrategy == RegistrationStrategy.preserveExisting;

    if (_getIt.isRegistered<T>()) {
      if (isPreserve && _lazySingletonDelegates.containsKey(T)) {
        _lazySingletonDelegates[T] = factory;
        return;
      }
      _ensureUnregistered<T>();
    }

    _lazySingletonDelegates[T] = factory;
    _trackExport<T>();
    _trackRegistration<T>();
    _getIt.registerLazySingleton<T>(() {
      final creator = _lazySingletonDelegates[T] as T Function()?;
      if (creator == null) {
        throw DependencyNotFoundException(
          'Factory for $T is not registered.',
          requestedType: T,
        );
      }
      return creator();
    });
  }

  @override
  void registerFactory<T extends Object>(T Function() factory) {
    _assertCanExport();
    final isPreserve =
        registrationStrategy == RegistrationStrategy.preserveExisting;

    if (_getIt.isRegistered<T>()) {
      if (isPreserve && _factoryDelegates.containsKey(T)) {
        _factoryDelegates[T] = factory;
        return;
      }
      _ensureUnregistered<T>();
    }

    _factoryDelegates[T] = factory;
    _trackExport<T>();
    _trackRegistration<T>();
    _getIt.registerFactory<T>(() {
      final creator = _factoryDelegates[T] as T Function()?;
      if (creator == null) {
        throw DependencyNotFoundException(
          'Factory for $T is not registered.',
          requestedType: T,
        );
      }
      return creator();
    });
  }

  @override
  void registerSingleton<T extends Object>(T instance) {
    _assertCanExport();
    final isPreserve =
        registrationStrategy == RegistrationStrategy.preserveExisting;

    if (_getIt.isRegistered<T>()) {
      if (isPreserve) {
        return;
      }
      _ensureUnregistered<T>();
    }

    _trackExport<T>();
    _trackRegistration<T>();
    _getIt.registerSingleton<T>(instance);
  }

  @override
  T get<T extends Object>() {
    final object = tryGet<T>();
    if (object == null) {
      throw DependencyNotFoundException(
        'Dependency of type $T not found in GetItBinder scope.',
        requestedType: T,
        lookupContext: 'GetItBinder scope',
      );
    }
    return object;
  }

  @override
  T parent<T extends Object>() {
    final object = tryParent<T>();
    if (object == null) {
      throw DependencyNotFoundException(
        'Dependency of type $T not found in parent scope.',
        requestedType: T,
        lookupContext: 'parent scope',
      );
    }
    return object;
  }

  @override
  T? tryGet<T extends Object>() {
    // 1. Local
    if (_getIt.isRegistered<T>()) {
      return _getIt<T>();
    }

    // 2. Imports
    for (final imported in _imports) {
      if (imported is ExportableBinder) {
        final found = imported.tryGetPublic<T>();
        if (found != null) return found;
      } else {
        // Fallback for other binder types
        final found = imported.tryGet<T>();
        if (found != null) return found;
      }
    }

    // 3. Parent
    return _parent?.tryGet<T>();
  }

  @override
  T? tryGetPublic<T extends Object>() {
    if (_exportedTypes.contains(T)) {
      if (_getIt.isRegistered<T>()) {
        return _getIt<T>();
      }
    }
    return null;
  }

  @override
  T? tryParent<T extends Object>() {
    return _parent?.tryGet<T>();
  }

  void _trackExport<T>() {
    if (_isExportMode) {
      _exportedTypes.add(T);
    }
  }

  void _trackRegistration<T extends Object>() {
    if (_useGlobalInstance) {
      _cleanupCallbacks.add(() async {
        if (_getIt.isRegistered<T>()) {
          await _getIt.unregister<T>();
        }
      });
    }
  }

  @override
  Future<void> dispose() => reset();

  /// Reset all registrations and clear internal tracking state.
  ///
  /// When using the global [GetIt] instance, only types registered through
  /// this binder are unregistered; otherwise the entire container is reset.
  Future<void> reset() async {
    if (_useGlobalInstance) {
      for (final callback in _cleanupCallbacks.reversed) {
        await callback();
      }
      _cleanupCallbacks.clear();
    } else {
      await _getIt.reset();
    }
    _exportedTypes.clear();
    _factoryDelegates.clear();
    _lazySingletonDelegates.clear();
  }

  @override
  RegistrationStrategy get registrationStrategy => _strategyStack.last;

  @override
  T runWithStrategy<T>(RegistrationStrategy strategy, T Function() body) {
    _strategyStack.add(strategy);
    try {
      return body();
    } finally {
      _strategyStack.removeLast();
    }
  }

  void _assertCanExport() {
    if (_isExportMode && _publicSealed) {
      throw ModuleConfigurationException(
        'Public scope is sealed. Call resetPublicScope() before registering new exports.',
      );
    }
  }

  void _ensureUnregistered<T extends Object>() {
    if (_getIt.isRegistered<T>()) {
      _factoryDelegates.remove(T);
      _lazySingletonDelegates.remove(T);
      _exportedTypes.remove(T);
      // unregister is sync unless a custom disposingFunction was provided.
      // Since we register without dispose callbacks, this is always sync.
      _getIt.unregister<T>();
    }
  }
}
