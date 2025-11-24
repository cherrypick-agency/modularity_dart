import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

class GetItBinder implements ExportableBinder {
  late final GetIt _getIt;
  final bool _useGlobalInstance;
  final List<FutureOr<void> Function()> _cleanupCallbacks = [];

  final Binder? _parent;
  final List<Binder> _imports = [];

  final Set<Type> _exportedTypes = {};
  bool _isExportMode = false;

  GetItBinder([this._parent, this._useGlobalInstance = false]) {
    _getIt = _useGlobalInstance ? GetIt.instance : GetIt.asNewInstance();
  }

  @override
  void enableExportMode() => _isExportMode = true;

  @override
  void disableExportMode() => _isExportMode = false;

  @override
  void addImports(List<Binder> binders) {
    _imports.addAll(binders);
  }

  @override
  bool contains(Type type) {
    // 1. Local
    if (_getIt.isRegistered(type: type)) return true;

    // 2. Imports
    for (final imported in _imports) {
      if (imported.contains(type)) return true;
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
    _trackExport<T>();
    _trackRegistration<T>();
    _getIt.registerLazySingleton<T>(factory);
  }

  @override
  void registerFactory<T extends Object>(T Function() factory) {
    _trackExport<T>();
    _trackRegistration<T>();
    _getIt.registerFactory<T>(factory);
  }

  @override
  void registerSingleton<T extends Object>(T instance) {
    _trackExport<T>();
    _trackRegistration<T>();
    _getIt.registerSingleton<T>(instance);
  }

  @override
  void singleton<T extends Object>(T Function() factory) =>
      registerLazySingleton(factory);

  @override
  void factory<T extends Object>(T Function() factory) =>
      registerFactory(factory);

  @override
  T get<T extends Object>() {
    final object = tryGet<T>();
    if (object == null) {
      throw Exception('Dependency of type $T not found in GetItBinder scope.');
    }
    return object;
  }

  @override
  T parent<T extends Object>() {
    final object = tryParent<T>();
    if (object == null) {
      throw Exception('Dependency of type $T not found in parent scope.');
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

  Future<void> reset() async {
    if (_useGlobalInstance) {
      for (final callback in _cleanupCallbacks.reversed) {
        await callback();
      }
      _cleanupCallbacks.clear();
    } else {
      await _getIt.reset();
    }
  }
}
