import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:modularity_get_it/modularity_get_it.dart';

class MyModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton(() => 'Bound with GetIt');
  }
}

void main() {
  // Create factory
  final factory = GetItBinderFactory(useGlobalInstance: false);

  // Create binder
  final binder = factory.create();

  // Register
  final module = MyModule();
  module.binds(binder);

  // Resolve
  print(binder.get<String>());
}
