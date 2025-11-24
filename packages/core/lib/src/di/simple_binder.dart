import 'package:modularity_contracts/modularity_contracts.dart';

enum _DependencyType { factory, singleton, instance }

class _Registration {
  final _DependencyType type;
  final Object Function() factory;
  Object? instance;

  _Registration({
    required this.type,
    required this.factory,
    this.instance,
  });
}

/// Простая реализация Binder на основе Map.
/// Поддерживает разделение на Public (Exports) и Private (Binds) зависимости.
class SimpleBinder implements ExportableBinder {
  final Map<Type, _Registration> _privateRegistrations = {};
  final Map<Type, _Registration> _publicRegistrations = {};

  /// Список импортированных модулей (их публичные биндеры).
  final List<Binder> _imports;
  
  /// Родительский биндер (Scope chaining).
  final Binder? _parent;

  /// Если true, регистрация идет в _publicRegistrations.
  bool _isExportMode = false;

  SimpleBinder({
    List<Binder> imports = const [],
    Binder? parent,
  })  : _imports = imports.toList(),
        _parent = parent;

  @override
  void addImports(List<Binder> binders) {
    _imports.addAll(binders);
  }

  /// Включает режим экспорта (регистрация в публичный скоуп).
  @override
  void enableExportMode() => _isExportMode = true;

  /// Выключает режим экспорта (регистрация в приватный скоуп).
  @override
  void disableExportMode() => _isExportMode = false;

  @override
  void factory<T extends Object>(T Function() factory) {
    _register<T>(_Registration(
      type: _DependencyType.factory,
      factory: factory,
    ));
  }

  @override
  void instance<T extends Object>(T instance) {
    _register<T>(_Registration(
      type: _DependencyType.instance,
      factory: () => instance,
      instance: instance,
    ));
  }

  @override
  void singleton<T extends Object>(T Function() factory) {
    _register<T>(_Registration(
      type: _DependencyType.singleton,
      factory: factory,
    ));
  }

  @override
  void eagerSingleton<T extends Object>(T Function() factory) {
    final instance = factory();
    _register<T>(_Registration(
      type: _DependencyType.singleton,
      factory: factory, // Keep factory for potential re-creation if needed?
      instance: instance,
    ));
  }

  void _register<T extends Object>(_Registration reg) {
    if (_isExportMode) {
      _publicRegistrations[T] = reg;
    } else {
      _privateRegistrations[T] = reg;
    }
  }

  @override
  T get<T extends Object>() {
    final object = tryGet<T>();
    if (object == null) {
      // DX Improvement: List available keys to help debugging
      final available = [
        ..._privateRegistrations.keys,
        ..._publicRegistrations.keys
      ].map((t) => t.toString()).join(', ');
      
      throw Exception(
          'Dependency of type $T not found.\n'
          'Checked: Current Scope, Imports, Parent.\n'
          'Available in Current Scope: [$available]'
      );
    }
    return object;
  }

  @override
  T? tryGet<T extends Object>() {
    // 1. Search locally (Private first, then Public)
    if (_privateRegistrations.containsKey(T)) {
      return _resolveRegistration<T>(_privateRegistrations[T]!);
    }
    if (_publicRegistrations.containsKey(T)) {
      return _resolveRegistration<T>(_publicRegistrations[T]!);
    }

    // 2. Search in imports (ONLY Public exports of imported modules)
    for (final importedBinder in _imports) {
      if (importedBinder is ExportableBinder) {
        final found = importedBinder.tryGetPublic<T>();
        if (found != null) return found;
      } else {
        final found = importedBinder.tryGet<T>();
        if (found != null) return found;
      }
    }
    
    // 3. Search in Parent (Implicit scope chaining)
    // Ищем в родителе как обычный get (он сам решит свои права доступа)
    final parentFound = _parent?.tryGet<T>();
    if (parentFound != null) return parentFound;

    return null;
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
  T? tryParent<T extends Object>() {
    return _parent?.tryGet<T>();
  }

  @override
  bool contains(Type type) {
    // 1. Local
    if (_privateRegistrations.containsKey(type) || _publicRegistrations.containsKey(type)) {
      return true;
    }

    // 2. Imports
    for (final importedBinder in _imports) {
       // Correctly check only public exports for imports
       if (importedBinder is ExportableBinder) {
         if (importedBinder.containsPublic(type)) return true;
       } else {
         if (importedBinder.contains(type)) return true;
       }
    }

    // 3. Parent
    if (_parent?.contains(type) == true) return true;

    return false;
  }
  
  /// Ищет ТОЛЬКО в публичных зависимостях (для использования другими модулями).
  @override
  T? tryGetPublic<T extends Object>() {
    if (_publicRegistrations.containsKey(T)) {
      return _resolveRegistration<T>(_publicRegistrations[T]!);
    }
    return null; 
  }

  @override
  bool containsPublic(Type type) {
    return _publicRegistrations.containsKey(type);
  }

  T _resolveRegistration<T extends Object>(_Registration reg) {
    if (reg.type == _DependencyType.instance) {
      return reg.instance as T;
    }

    if (reg.type == _DependencyType.singleton) {
      if (reg.instance == null) {
        reg.instance = reg.factory();
      }
      return reg.instance as T;
    }

    // Factory
    return reg.factory() as T;
  }

  /// Очистка ресурсов.
  void dispose() {
    _privateRegistrations.clear();
    _publicRegistrations.clear();
  }
}
