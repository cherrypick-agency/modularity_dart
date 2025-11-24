import 'package:get_it/get_it.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

class GetItBinder implements ExportableBinder {
  /// Используем отдельный инстанс GetIt для каждого модуля для изоляции.
  final GetIt _getIt = GetIt.asNewInstance();

  final Binder? _parent;
  final List<Binder> _imports = [];

  final Set<Type> _exportedTypes = {};
  bool _isExportMode = false;

  GetItBinder([this._parent]);

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
  void eagerSingleton<T extends Object>(T Function() factory) {
    _trackExport<T>();
    // GetIt не имеет явного eagerSingleton, регистрируем как singleton с готовым инстансом
    _getIt.registerSingleton<T>(factory());
  }

  @override
  void factory<T extends Object>(T Function() factory) {
    _trackExport<T>();
    _getIt.registerFactory<T>(factory);
  }

  @override
  T get<T extends Object>() {
    final object = tryGet<T>();
    if (object == null) {
      throw Exception('Dependency of type $T not found in GetItBinder scope.');
    }
    return object;
  }

  @override
  void instance<T extends Object>(T instance) {
    _trackExport<T>();
    _getIt.registerSingleton<T>(instance);
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
  void singleton<T extends Object>(T Function() factory) {
    _trackExport<T>();
    _getIt.registerLazySingleton<T>(factory);
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

  Future<void> reset() async {
    await _getIt.reset();
  }
}
