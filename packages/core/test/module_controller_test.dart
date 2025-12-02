import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:modularity_core/modularity_core.dart';
import 'package:test/test.dart';

class PublicService {}

class ProviderModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<PublicService>(() => PublicService());
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<PublicService>(() => i.get<PublicService>());
  }
}

class ConsumerModule extends Module {
  PublicService? resolved;

  @override
  List<Module> get imports => [ProviderModule()];

  @override
  List<Type> get expects => [PublicService];

  @override
  void binds(Binder i) {
    resolved = i.get<PublicService>();
    i.registerSingleton<PublicService>(resolved!);
  }
}

class MissingDependencyModule extends Module {
  @override
  List<Type> get expects => [PublicService];

  @override
  void binds(Binder i) {
    // Нет импорта и регистраций — должно упасть до binds.
  }
}

void main() {
  group('ModuleController + SimpleBinder integration', () {
    test('imports expose exported dependencies to consumers', () async {
      final registry = <Type, ModuleController>{};
      final consumerController = ModuleController(ConsumerModule());

      await consumerController.initialize(registry);

      expect(
        consumerController.binder.get<PublicService>(),
        isA<PublicService>(),
      );
      final module = consumerController.module as ConsumerModule;
      expect(module.resolved, isNotNull);
    });

    test('throws when expects are missing in imports/parent', () async {
      final registry = <Type, ModuleController>{};
      final controller = ModuleController(MissingDependencyModule());

      await expectLater(
        () => controller.initialize(registry),
        throwsA(isA<Exception>()),
      );
    });

    test('hotReload rebinds without duplicate export errors', () async {
      final registry = <Type, ModuleController>{};
      final controller = ModuleController(ConsumerModule());

      await controller.initialize(registry);
      controller.hotReload();

      expect(
        controller.binder.get<PublicService>(),
        isA<PublicService>(),
      );
    });
  });
}
