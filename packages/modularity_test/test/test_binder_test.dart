import 'package:test/test.dart';
import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_test/modularity_test.dart';

class TestModule extends Module {
  @override
  void binds(Binder i) {
    i.singleton<String>(() => 'singleton');
    i.factory<int>(() => 42);
  }
}

void main() {
  group('TestBinder', () {
    test('should record registrations', () {
      final realBinder = SimpleBinderFactory().create();
      final testBinder = TestBinder(realBinder);

      testBinder.singleton<String>(() => 'test');
      testBinder.factory<int>(() => 1);
      testBinder.eagerSingleton<bool>(() => true);
      testBinder.instance<double>(1.0);

      expect(testBinder.hasSingleton<String>(), isTrue);
      expect(testBinder.hasFactory<int>(), isTrue);
      expect(testBinder.hasEagerSingleton<bool>(), isTrue);
      expect(testBinder.hasInstance<double>(), isTrue);

      expect(testBinder.registeredSingletons, contains(String));
      expect(testBinder.registeredFactories, contains(int));
    });

    test('should delegate to real binder', () {
      final realBinder = SimpleBinderFactory().create();
      final testBinder = TestBinder(realBinder);

      testBinder.instance<String>('value');
      expect(realBinder.get<String>(), equals('value'));
      expect(testBinder.get<String>(), equals('value'));
    });

    test('should record resolutions', () {
      final realBinder = SimpleBinderFactory().create();
      final testBinder = TestBinder(realBinder);

      testBinder.instance<String>('value');
      testBinder.get<String>();

      expect(testBinder.wasResolved<String>(), isTrue);
      expect(testBinder.resolvedTypes, contains(String));
    });
  });

  group('testModule', () {
    test('should provide TestBinder with recorded registrations', () async {
      await testModule(TestModule(), (module, binder) {
        expect(binder.hasSingleton<String>(), isTrue);
        expect(binder.hasFactory<int>(), isTrue);

        expect(binder.get<String>(), equals('singleton'));
        expect(binder.get<int>(), equals(42));

        expect(binder.wasResolved<String>(), isTrue);
      });
    });
  });
}
