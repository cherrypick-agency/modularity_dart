import 'package:modularity_contracts/modularity_contracts.dart';

/// A Proxy Binder implementation that records all interactions.
/// Useful for testing module behavior.
class TestBinder implements Binder {
  final Binder _delegate;
  
  final List<Type> _registeredSingletons = [];
  final List<Type> _registeredEagerSingletons = [];
  final List<Type> _registeredFactories = [];
  final List<Type> _registeredInstances = [];
  final List<Type> _resolvedTypes = [];

  TestBinder(this._delegate);

  /// List of types registered as Singletons.
  List<Type> get registeredSingletons => List.unmodifiable(_registeredSingletons);
  
  /// List of types registered as Eager Singletons.
  List<Type> get registeredEagerSingletons => List.unmodifiable(_registeredEagerSingletons);
  
  /// List of types registered as Factories.
  List<Type> get registeredFactories => List.unmodifiable(_registeredFactories);
  
  /// List of types registered as Instances.
  List<Type> get registeredInstances => List.unmodifiable(_registeredInstances);
  
  /// List of types that were resolved (get/tryGet).
  List<Type> get resolvedTypes => List.unmodifiable(_resolvedTypes);

  @override
  void singleton<T extends Object>(T Function() factory) {
    _registeredSingletons.add(T);
    _delegate.singleton<T>(factory);
  }

  @override
  void eagerSingleton<T extends Object>(T Function() factory) {
    _registeredEagerSingletons.add(T);
    _delegate.eagerSingleton<T>(factory);
  }

  @override
  void factory<T extends Object>(T Function() factory) {
    _registeredFactories.add(T);
    _delegate.factory<T>(factory);
  }

  @override
  void instance<T extends Object>(T instance) {
    _registeredInstances.add(T);
    _delegate.instance<T>(instance);
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
  
  /// Checks if a type was registered as Singleton.
  bool hasSingleton<T>() => _registeredSingletons.contains(T);

  /// Checks if a type was registered as Eager Singleton.
  bool hasEagerSingleton<T>() => _registeredEagerSingletons.contains(T);
  
  /// Checks if a type was registered as Factory.
  bool hasFactory<T>() => _registeredFactories.contains(T);
  
  /// Checks if a type was registered as Instance.
  bool hasInstance<T>() => _registeredInstances.contains(T);
  
  /// Checks if a type was resolved.
  bool wasResolved<T>() => _resolvedTypes.contains(T);
}

