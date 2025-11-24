import 'package:test/test.dart';
import 'package:get_it/get_it.dart';
import 'package:modularity_get_it/modularity_get_it.dart';

void main() {
  group('GetItBinder', () {
    tearDown(() async {
      await GetIt.instance.reset();
    });

    test('Isolated Mode (default): registers in new instance', () {
      final binder =
          GetItBinderFactory(useGlobalInstance: false).create() as GetItBinder;

      binder.registerSingleton<String>('isolated');

      expect(binder.get<String>(), 'isolated');
      // Should NOT be in global GetIt
      expect(GetIt.instance.isRegistered<String>(), isFalse);
    });

    test('Global Mode: registers in global instance', () {
      final binder =
          GetItBinderFactory(useGlobalInstance: true).create() as GetItBinder;

      binder.registerSingleton<String>('global');

      expect(binder.get<String>(), 'global');
      // Should BE in global GetIt
      expect(GetIt.instance.isRegistered<String>(), isTrue);
      expect(GetIt.instance<String>(), 'global');
    });

    test('Global Mode: reset() clears ONLY registered types', () async {
      final binder =
          GetItBinderFactory(useGlobalInstance: true).create() as GetItBinder;

      // Register something externally
      GetIt.instance.registerSingleton<int>(42);

      // Register via binder
      binder.registerSingleton<String>('mine');

      expect(GetIt.instance.isRegistered<int>(), isTrue);
      expect(GetIt.instance.isRegistered<String>(), isTrue);

      await binder.reset();

      // 'mine' should be gone
      expect(GetIt.instance.isRegistered<String>(), isFalse);
      // 'int' should stay
      expect(GetIt.instance.isRegistered<int>(), isTrue);
    });
  });
}
