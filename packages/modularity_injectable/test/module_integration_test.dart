import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:test/test.dart';

class PublicApi {}

class PrivateImpl {}

class ProviderModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<PrivateImpl>(() => PrivateImpl());
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<PublicApi>(() => PublicApi());
  }
}

class ConsumerModule extends Module {
  PublicApi? resolved;

  @override
  List<Module> get imports => [ProviderModule()];

  @override
  List<Type> get expects => [PublicApi];

  @override
  void binds(Binder i) {
    resolved = i.get<PublicApi>();
  }
}

class StandaloneModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<PrivateImpl>(() => PrivateImpl());
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<PublicApi>(() => PublicApi());
  }
}

void main() {
  group('ModuleController + GetItBinder integration', () {
    test('full init/binds/exports/dispose cycle', () async {
      final module = StandaloneModule();
      final binder = GetItBinder();
      final controller = ModuleController(module, binder: binder);
      final registry = <ModuleRegistryKey, ModuleController>{};

      expect(controller.currentStatus, equals(ModuleStatus.initial));

      await controller.initialize(registry);

      expect(controller.currentStatus, equals(ModuleStatus.loaded));
      expect(binder.get<PrivateImpl>(), isA<PrivateImpl>());
      expect(binder.tryGetPublic<PublicApi>(), isA<PublicApi>());

      await controller.dispose();

      expect(controller.currentStatus, equals(ModuleStatus.disposed));
    });

    test(
      'import chain with GetItBinder: provider -> consumer with expects',
      () async {
        final registry = <ModuleRegistryKey, ModuleController>{};

        final providerBinder = GetItBinder();
        final providerController = ModuleController(
          ProviderModule(),
          binder: providerBinder,
          binderFactory: const GetItBinderFactory(),
        );

        final consumerModule = ConsumerModule();
        final consumerBinder = GetItBinder();
        final consumerController = ModuleController(
          consumerModule,
          binder: consumerBinder,
          binderFactory: const GetItBinderFactory(),
        );

        await consumerController.initialize(registry);

        expect(consumerModule.resolved, isA<PublicApi>());
        expect(consumerController.currentStatus, equals(ModuleStatus.loaded));

        await providerController.dispose();
        await consumerController.dispose();
      },
    );

    test('hot reload with GetItBinder rebinds without errors', () async {
      final module = StandaloneModule();
      final binder = GetItBinder();
      final controller = ModuleController(module, binder: binder);
      final registry = <ModuleRegistryKey, ModuleController>{};

      // Verify GetItBinder is recognized as ExportableBinder
      expect(binder, isA<ExportableBinder>());

      await controller.initialize(registry);

      final firstApi = binder.tryGetPublic<PublicApi>();
      expect(firstApi, isA<PublicApi>());

      // hotReload calls resetPublicScope internally
      controller.hotReload();

      final secondApi = binder.tryGetPublic<PublicApi>();
      expect(secondApi, isA<PublicApi>());
      expect(controller.currentStatus, equals(ModuleStatus.loaded));

      await controller.dispose();
    });

    test('GetItBinderFactory creates GetItBinder instances', () {
      const factory = GetItBinderFactory();

      final binder = factory.create();
      expect(binder, isA<GetItBinder>());

      final parentBinder = GetItBinder();
      final childBinder = factory.create(parentBinder);
      expect(childBinder, isA<GetItBinder>());

      (binder as GetItBinder).dispose();
      (childBinder as GetItBinder).dispose();
      parentBinder.dispose();
    });

    test('private dependencies invisible to importing module', () async {
      final registry = <ModuleRegistryKey, ModuleController>{};

      final providerBinder = GetItBinder();
      final providerController = ModuleController(
        ProviderModule(),
        binder: providerBinder,
        binderFactory: const GetItBinderFactory(),
      );

      await providerController.initialize(registry);

      final consumerBinder = GetItBinder(imports: [providerBinder]);

      // Private dependencies from provider are not visible to consumer
      expect(consumerBinder.tryGet<PrivateImpl>(), isNull);
      // Public dependencies from provider are visible via tryGet (through imports)
      expect(consumerBinder.tryGet<PublicApi>(), isA<PublicApi>());
      // tryGetPublic only checks local public scope, not imports
      expect(consumerBinder.tryGetPublic<PublicApi>(), isNull);

      await providerController.dispose();
      consumerBinder.dispose();
    });
  });
}
