import 'package:test/test.dart';
import 'package:modularity_core/modularity_core.dart';

class Service {
  static int instanceCount = 0;
  Service() {
    instanceCount++;
  }
}

void main() {
  group('SimpleBinder Eager Singleton', () {
    late SimpleBinder binder;

    setUp(() {
      binder = SimpleBinder();
      Service.instanceCount = 0;
    });

    test('lazy singleton is NOT created until get()', () {
      binder.singleton<Service>(() => Service());
      expect(Service.instanceCount, 0);

      binder.get<Service>();
      expect(Service.instanceCount, 1);
    });

    test('eager singleton IS created immediately', () {
      binder.eagerSingleton<Service>(() => Service());
      expect(Service.instanceCount, 1);

      binder.get<Service>();
      expect(Service.instanceCount, 1);
    });

    test('eager singleton persists across get calls', () {
      binder.eagerSingleton<Service>(() => Service());
      final s1 = binder.get<Service>();
      final s2 = binder.get<Service>();

      expect(s1, equals(s2));
      expect(Service.instanceCount, 1);
    });
  });
}
