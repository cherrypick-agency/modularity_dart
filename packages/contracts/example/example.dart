import 'package:modularity_contracts/modularity_contracts.dart';

/// A simple module implementation example.
class MyModule extends Module {
  @override
  void binds(Binder binder) {
    // Register a lazy singleton
    binder.registerLazySingleton<MyService>(() => MyService());

    // Register a factory
    binder.registerFactory<MyHelper>(() => MyHelper());
  }
}

class MyService {
  void doWork() => print('Working...');
}

class MyHelper {
  void help() => print('Helping...');
}

void main() {
  final module = MyModule();
  final binder = _MockBinder();

  // Manually calling binds for example purposes
  module.binds(binder);

  final service = binder.get<MyService>();
  service.doWork();
}

class _MockBinder implements Binder {
  final Map<Type, dynamic> _instances = {};

  @override
  void registerLazySingleton<T extends Object>(T Function() factory) {
    print('Registered singleton ${T.toString()}');
    _instances[T] = factory();
  }

  @override
  void registerFactory<T extends Object>(T Function() factory) {
    print('Registered factory ${T.toString()}');
  }

  @override
  void registerSingleton<T extends Object>(T instance) {
    print('Registered instance ${T.toString()}');
    _instances[T] = instance;
  }

  @override
  T get<T extends Object>() {
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }
    throw Exception('Dependency not found');
  }

  @override
  void addImports(List<Binder> binders) {}

  @override
  bool contains(Type type) => _instances.containsKey(type);

  @override
  T parent<T extends Object>() => throw UnimplementedError();

  @override
  T? tryGet<T extends Object>() => _instances[T] as T?;

  @override
  T? tryParent<T extends Object>() => null;
}
