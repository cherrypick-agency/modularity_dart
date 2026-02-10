import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_test/modularity_test.dart';
import 'package:test/test.dart';

class MyService {}

class MyModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton(() => MyService());
  }
}

void main() {
  test('MyModule registers MyService', () async {
    await testModule(MyModule(), (module, binder) async {
      final service = binder.get<MyService>();
      expect(service, isA<MyService>());
    });
  });
}
