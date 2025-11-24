import 'package:test/test.dart';
import 'package:modularity_core/modularity_core.dart';

class Service {
  static int instanceCount = 0;
  Service() {
    instanceCount++;
  }
}

void main() {
  group('SimpleBinder Eager Singleton (now registerSingleton)', () {
    late SimpleBinder binder;

    setUp(() {
      binder = SimpleBinder();
      Service.instanceCount = 0;
    });

    test('lazy singleton is NOT created until get()', () {
      binder.registerLazySingleton<Service>(() => Service());
      expect(Service.instanceCount, 0);

      binder.get<Service>();
      expect(Service.instanceCount, 1);
    });

    test('registerSingleton (eager) IS created immediately', () {
      // Eager logic is now: create instance -> register
      binder.registerSingleton<Service>(Service());
      expect(Service.instanceCount, 1);

      binder.get<Service>();
      expect(Service.instanceCount, 1);
    });

    test('registerSingleton persists across get calls', () {
      final service = Service();
      binder.registerSingleton<Service>(service);

      final s1 = binder.get<Service>();
      final s2 = binder.get<Service>();

      expect(s1, equals(s2));
      expect(s1, equals(service));
      expect(Service.instanceCount, 1);
    });
  });
}
