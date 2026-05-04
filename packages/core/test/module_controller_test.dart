import 'dart:async';
import 'package:modularity_core/modularity_core.dart';
import 'package:test/test.dart';

class PublicService {}

class PrivateImpl {}

class HotReloadFactory {
  HotReloadFactory(this.version);
  final int version;
}

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
  void binds(Binder i) {}
}

class LifecycleOrderModule extends Module {
  final List<String> callOrder = [];

  @override
  void binds(Binder i) {
    callOrder.add('binds');
    i.registerLazySingleton<PrivateImpl>(() => PrivateImpl());
  }

  @override
  void exports(Binder i) {
    callOrder.add('exports');
    i.registerLazySingleton<PublicService>(() => PublicService());
  }

  @override
  Future<void> onInit() async {
    callOrder.add('onInit');
  }
}

class FailingBindsModule extends Module {
  @override
  void binds(Binder i) {
    throw Exception('binds error');
  }
}

class FailingOnInitModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<PrivateImpl>(() => PrivateImpl());
  }

  @override
  Future<void> onInit() async {
    throw Exception('onInit error');
  }
}

class SlowInitModule extends Module {
  SlowInitModule(this.allowInit);

  final Completer<void> allowInit;
  int initCount = 0;
  int disposeCount = 0;

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    initCount++;
    await allowInit.future;
  }

  @override
  void onDispose() {
    disposeCount++;
  }
}

class AsyncDisposeModule extends Module {
  AsyncDisposeModule(this.allowDispose);

  final Completer<void> allowDispose;
  bool disposed = false;

  @override
  void binds(Binder i) {}

  @override
  Future<void> onDispose() async {
    await allowDispose.future;
    disposed = true;
  }
}

class _TestInterceptor implements ModuleInterceptor {
  final List<String> events = [];

  @override
  void onInit(Module module) => events.add('onInit:${module.runtimeType}');

  @override
  void onLoaded(Module module) => events.add('onLoaded:${module.runtimeType}');

  @override
  void onError(Module module, Object error) =>
      events.add('onError:${module.runtimeType}');

  @override
  void onDispose(Module module) =>
      events.add('onDispose:${module.runtimeType}');
}

class ThrowingOnInitInterceptor implements ModuleInterceptor {
  @override
  void onInit(Module module) {
    throw Exception('interceptor onInit failed');
  }

  @override
  void onLoaded(Module module) {}

  @override
  void onError(Module module, Object error) {}

  @override
  void onDispose(Module module) {}
}

class ThrowingOnErrorInterceptor implements ModuleInterceptor {
  @override
  void onInit(Module module) {}

  @override
  void onLoaded(Module module) {}

  @override
  void onError(Module module, Object error) {
    throw Exception('interceptor onError failed');
  }

  @override
  void onDispose(Module module) {}
}

class OverridableModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<PublicService>(() => PublicService());
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<PublicService>(() => i.get<PublicService>());
  }
}

class MockPublicService extends PublicService {}

class ConfigData {
  ConfigData(this.value);
  final String value;
}

class ConfigurableModule extends Module implements Configurable<ConfigData> {
  ConfigData? config;

  @override
  void configure(ConfigData args) {
    config = args;
  }

  @override
  void binds(Binder i) {
    i.registerSingleton<ConfigData>(config!);
  }
}

class CircularA extends Module {
  @override
  List<Module> get imports => [CircularB()];

  @override
  void binds(Binder i) {}
}

class CircularB extends Module {
  @override
  List<Module> get imports => [CircularA()];

  @override
  void binds(Binder i) {}
}

class HotReloadModule extends Module {
  int bindsCount = 0;

  @override
  void binds(Binder i) {
    bindsCount++;
    i
      ..registerLazySingleton<PublicService>(() => PublicService())
      ..registerFactory<HotReloadFactory>(() => HotReloadFactory(bindsCount));
  }
}

class ChildOverridesModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<PublicService>(() => PublicService());
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<PublicService>(() => i.get<PublicService>());
  }
}

class ParentOverridesModule extends Module {
  PublicService? resolved;

  @override
  List<Module> get imports => [ChildOverridesModule()];

  @override
  void binds(Binder i) {
    resolved = i.get<PublicService>();
  }
}

class MockService extends PublicService {}

class AnotherMockService extends PublicService {}

class SharedDisposableModule extends Module {
  static int initCount = 0;
  static int disposeCount = 0;

  static void resetCounts() {
    initCount = 0;
    disposeCount = 0;
  }

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    initCount++;
  }

  @override
  void onDispose() {
    disposeCount++;
  }
}

class FirstSharedConsumerModule extends Module {
  @override
  List<Module> get imports => [SharedDisposableModule()];

  @override
  void binds(Binder i) {}
}

class SecondSharedConsumerModule extends Module {
  @override
  List<Module> get imports => [SharedDisposableModule()];

  @override
  void binds(Binder i) {}
}

void main() {
  group('ModuleRegistryKey', () {
    test('equal when same type and null overrideScope', () {
      final key1 = ModuleRegistryKey(moduleType: ProviderModule);
      final key2 = ModuleRegistryKey(moduleType: ProviderModule);

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('equal when same type and identical overrideScope', () {
      final scope = ModuleOverrideScope(selfOverrides: (binder) {});
      final key1 = ModuleRegistryKey(
        moduleType: ProviderModule,
        overrideScope: scope,
      );
      final key2 = ModuleRegistryKey(
        moduleType: ProviderModule,
        overrideScope: scope,
      );

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('not equal when different types', () {
      final key1 = ModuleRegistryKey(moduleType: ProviderModule);
      final key2 = ModuleRegistryKey(moduleType: ConsumerModule);

      expect(key1, isNot(equals(key2)));
    });

    test('not equal when different overrideScope instances', () {
      final scope1 = ModuleOverrideScope(selfOverrides: (binder) {});
      final scope2 = ModuleOverrideScope(selfOverrides: (binder) {});
      final key1 = ModuleRegistryKey(
        moduleType: ProviderModule,
        overrideScope: scope1,
      );
      final key2 = ModuleRegistryKey(
        moduleType: ProviderModule,
        overrideScope: scope2,
      );

      expect(key1, isNot(equals(key2)));
    });

    test('equal when same type and same moduleIdentity', () {
      final key1 = ModuleRegistryKey(
        moduleType: ProviderModule,
        moduleIdentity: 'profile:1',
      );
      final key2 = ModuleRegistryKey(
        moduleType: ProviderModule,
        moduleIdentity: 'profile:1',
      );

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('not equal when different moduleIdentity values', () {
      final key1 = ModuleRegistryKey(
        moduleType: ProviderModule,
        moduleIdentity: 'profile:1',
      );
      final key2 = ModuleRegistryKey(
        moduleType: ProviderModule,
        moduleIdentity: 'profile:2',
      );

      expect(key1, isNot(equals(key2)));
    });

    test('graph node key ignores overrideScope and uses module identity', () {
      const node1 = ModuleGraphNodeKey(
        moduleType: ProviderModule,
        moduleIdentity: 'tenant-a',
      );
      const node2 = ModuleGraphNodeKey(
        moduleType: ProviderModule,
        moduleIdentity: 'tenant-a',
      );
      const node3 = ModuleGraphNodeKey(
        moduleType: ProviderModule,
        moduleIdentity: 'tenant-b',
      );

      expect(node1, equals(node2));
      expect(node1, isNot(equals(node3)));
    });

    test('not equal when one has null overrideScope and other does not', () {
      final scope = ModuleOverrideScope(selfOverrides: (binder) {});
      final key1 = ModuleRegistryKey(moduleType: ProviderModule);
      final key2 = ModuleRegistryKey(
        moduleType: ProviderModule,
        overrideScope: scope,
      );

      expect(key1, isNot(equals(key2)));
    });

    test('works correctly as Map key', () {
      final registry = <ModuleRegistryKey, String>{};
      final scope = ModuleOverrideScope(selfOverrides: (binder) {});

      final key1 = ModuleRegistryKey(moduleType: ProviderModule);
      final key2 = ModuleRegistryKey(
        moduleType: ProviderModule,
        overrideScope: scope,
      );
      final key3 = ModuleRegistryKey(moduleType: ConsumerModule);

      registry[key1] = 'default';
      registry[key2] = 'with-scope';
      registry[key3] = 'consumer';

      expect(registry.length, equals(3));
      expect(registry[key1], equals('default'));
      expect(registry[key2], equals('with-scope'));
      expect(registry[key3], equals('consumer'));

      // Same key retrieves same value
      final key1Copy = ModuleRegistryKey(moduleType: ProviderModule);
      expect(registry[key1Copy], equals('default'));
    });
  });

  group('ModuleController + SimpleBinder integration', () {
    test('imports expose exported dependencies to consumers', () async {
      final registry = <ModuleRegistryKey, ModuleController>{};
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
      final registry = <ModuleRegistryKey, ModuleController>{};
      final controller = ModuleController(MissingDependencyModule());

      await expectLater(
        () => controller.initialize(registry),
        throwsA(isA<Exception>()),
      );
    });

    test('hotReload rebinds without duplicate export errors', () async {
      final registry = <ModuleRegistryKey, ModuleController>{};
      final controller = ModuleController(ConsumerModule());

      await controller.initialize(registry);
      controller.hotReload();

      expect(controller.binder.get<PublicService>(), isA<PublicService>());
    });

    test(
      'hotReload preserves singleton instances and updates factories',
      () async {
        final registry = <ModuleRegistryKey, ModuleController>{};
        final controller = ModuleController(HotReloadModule());

        await controller.initialize(registry);

        final singleton1 = controller.binder.get<PublicService>();
        final factory1 = controller.binder.get<HotReloadFactory>();
        expect(factory1.version, equals(1));

        controller.hotReload();

        final singleton2 = controller.binder.get<PublicService>();
        final factory2 = controller.binder.get<HotReloadFactory>();

        expect(singleton2, same(singleton1));
        expect(factory2.version, equals(2));
      },
    );

    test('child override scope applies overrides to imports', () async {
      final registry = <ModuleRegistryKey, ModuleController>{};
      final overrideScope = ModuleOverrideScope(
        children: {
          ChildOverridesModule: ModuleOverrideScope(
            selfOverrides: (binder) {
              binder.registerLazySingleton<PublicService>(() => MockService());
            },
          ),
        },
      );

      final controller = ModuleController(
        ParentOverridesModule(),
        overrideScopeTree: overrideScope,
      );

      await controller.initialize(registry);
      final module = controller.module as ParentOverridesModule;

      expect(module.resolved, isA<MockService>());
    });

    test('child override scope stays isolated per controller', () async {
      final registry = <ModuleRegistryKey, ModuleController>{};

      final overrideScopeA = ModuleOverrideScope(
        children: {
          ChildOverridesModule: ModuleOverrideScope(
            selfOverrides: (binder) {
              binder.registerLazySingleton<PublicService>(() => MockService());
            },
          ),
        },
      );

      final overrideScopeB = ModuleOverrideScope(
        children: {
          ChildOverridesModule: ModuleOverrideScope(
            selfOverrides: (binder) {
              binder.registerLazySingleton<PublicService>(
                () => AnotherMockService(),
              );
            },
          ),
        },
      );

      final controllerA = ModuleController(
        ParentOverridesModule(),
        overrideScopeTree: overrideScopeA,
      );
      final controllerB = ModuleController(
        ParentOverridesModule(),
        overrideScopeTree: overrideScopeB,
      );

      await controllerA.initialize(registry);
      await controllerB.initialize(registry);

      expect(
        (controllerA.module as ParentOverridesModule).resolved,
        isA<MockService>(),
      );
      expect(
        (controllerB.module as ParentOverridesModule).resolved,
        isA<AnotherMockService>(),
      );

      await controllerA.dispose();
      await controllerB.dispose();
    });
  });

  group('ModuleController lifecycle', () {
    test('binds called before exports before onInit', () async {
      final module = LifecycleOrderModule();
      final controller = ModuleController(module);
      final registry = <ModuleRegistryKey, ModuleController>{};

      await controller.initialize(registry);

      expect(module.callOrder, equals(['binds', 'exports', 'onInit']));
    });

    test('status transitions initial -> loading -> loaded', () async {
      final module = LifecycleOrderModule();
      final controller = ModuleController(module);
      final registry = <ModuleRegistryKey, ModuleController>{};

      final statuses = <ModuleStatus>[];
      controller.status.listen(statuses.add);

      expect(controller.currentStatus, equals(ModuleStatus.initial));

      await controller.initialize(registry);

      expect(statuses, contains(ModuleStatus.loading));
      expect(controller.currentStatus, equals(ModuleStatus.loaded));
    });

    test('status error on exception in binds', () async {
      final controller = ModuleController(FailingBindsModule());
      final registry = <ModuleRegistryKey, ModuleController>{};

      await expectLater(
        () => controller.initialize(registry),
        throwsA(isA<Exception>()),
      );

      expect(controller.currentStatus, equals(ModuleStatus.error));
      expect(controller.lastError, isNotNull);
    });

    test('status error on exception in onInit', () async {
      final controller = ModuleController(FailingOnInitModule());
      final registry = <ModuleRegistryKey, ModuleController>{};

      await expectLater(
        () => controller.initialize(registry),
        throwsA(isA<Exception>()),
      );

      expect(controller.currentStatus, equals(ModuleStatus.error));
    });

    test('concurrent initialize calls share the same initialization', () async {
      final allowInit = Completer<void>();
      final module = SlowInitModule(allowInit);
      final controller = ModuleController(module);
      final registry = <ModuleRegistryKey, ModuleController>{};

      final first = controller.initialize(registry);
      final second = controller.initialize(registry);

      expect(second, same(first));
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentStatus, equals(ModuleStatus.loading));
      expect(module.initCount, equals(1));

      allowInit.complete();
      await Future.wait([first, second]);

      expect(controller.currentStatus, equals(ModuleStatus.loaded));
      expect(module.initCount, equals(1));
    });

    test('dispose during initialization waits and finishes disposed', () async {
      final allowInit = Completer<void>();
      final module = SlowInitModule(allowInit);
      final controller = ModuleController(module);
      final registry = <ModuleRegistryKey, ModuleController>{};

      final initFuture = controller.initialize(registry);
      await Future<void>.delayed(Duration.zero);

      final disposeFuture = controller.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentStatus, equals(ModuleStatus.loading));
      expect(module.disposeCount, equals(0));

      allowInit.complete();
      await initFuture;
      await disposeFuture;

      expect(controller.currentStatus, equals(ModuleStatus.disposed));
      expect(module.disposeCount, equals(1));
    });

    test('initialize after dispose throws lifecycle exception', () async {
      final controller = ModuleController(LifecycleOrderModule());
      final registry = <ModuleRegistryKey, ModuleController>{};

      await controller.initialize(registry);
      await controller.dispose();

      await expectLater(
        () => controller.initialize(registry),
        throwsA(isA<ModuleLifecycleException>()),
      );
      expect(controller.currentStatus, equals(ModuleStatus.disposed));
    });

    test(
      'initialize after failed initialization throws lifecycle exception',
      () async {
        final controller = ModuleController(FailingOnInitModule());
        final registry = <ModuleRegistryKey, ModuleController>{};

        await expectLater(
          () => controller.initialize(registry),
          throwsA(isA<Exception>()),
        );

        await expectLater(
          () => controller.initialize(registry),
          throwsA(isA<ModuleLifecycleException>()),
        );
        expect(controller.currentStatus, equals(ModuleStatus.error));
      },
    );
  });

  group('ModuleController interceptors', () {
    test('interceptors receive lifecycle events', () async {
      final interceptor = _TestInterceptor();
      final module = LifecycleOrderModule();
      final controller = ModuleController(module, interceptors: [interceptor]);
      final registry = <ModuleRegistryKey, ModuleController>{};

      await controller.initialize(registry);

      expect(interceptor.events, contains('onInit:LifecycleOrderModule'));
      expect(interceptor.events, contains('onLoaded:LifecycleOrderModule'));
    });

    test('interceptors receive onError on failure', () async {
      final interceptor = _TestInterceptor();
      final controller = ModuleController(
        FailingBindsModule(),
        interceptors: [interceptor],
      );
      final registry = <ModuleRegistryKey, ModuleController>{};

      await expectLater(
        () => controller.initialize(registry),
        throwsA(isA<Exception>()),
      );

      expect(interceptor.events, contains('onError:FailingBindsModule'));
    });

    test('onInit interceptor failures move controller to error', () async {
      final controller = ModuleController(
        LifecycleOrderModule(),
        interceptors: [ThrowingOnInitInterceptor()],
      );
      final registry = <ModuleRegistryKey, ModuleController>{};

      await expectLater(
        () => controller.initialize(registry),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('interceptor onInit failed'),
          ),
        ),
      );

      expect(controller.currentStatus, equals(ModuleStatus.error));
      expect(controller.lastError.toString(), contains('interceptor onInit'));
    });

    test('onError interceptor failures do not mask original error', () async {
      final controller = ModuleController(
        FailingBindsModule(),
        interceptors: [ThrowingOnErrorInterceptor()],
      );
      final registry = <ModuleRegistryKey, ModuleController>{};

      await expectLater(
        () => controller.initialize(registry),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('binds error'),
          ),
        ),
      );

      expect(controller.currentStatus, equals(ModuleStatus.error));
      expect(controller.lastError.toString(), contains('binds error'));
    });

    test('interceptors receive onDispose', () async {
      final interceptor = _TestInterceptor();
      final module = LifecycleOrderModule();
      final controller = ModuleController(module, interceptors: [interceptor]);
      final registry = <ModuleRegistryKey, ModuleController>{};

      await controller.initialize(registry);
      await controller.dispose();

      expect(interceptor.events, contains('onDispose:LifecycleOrderModule'));
    });
  });

  group('ModuleController overrides', () {
    test('overrides applied after binds before exports', () async {
      final controller = ModuleController(
        OverridableModule(),
        overrides: (binder) {
          binder.registerSingleton<PublicService>(MockPublicService());
        },
      );
      final registry = <ModuleRegistryKey, ModuleController>{};

      await controller.initialize(registry);

      expect(controller.binder.get<PublicService>(), isA<MockPublicService>());
    });
  });

  group('ModuleController configurable', () {
    test('configure called with args', () async {
      final module = ConfigurableModule();
      final controller = ModuleController(module);
      final registry = <ModuleRegistryKey, ModuleController>{};

      controller.configure(ConfigData('test_value'));
      await controller.initialize(registry);

      expect(module.config?.value, equals('test_value'));
      expect(controller.binder.get<ConfigData>().value, equals('test_value'));
    });

    test('wrong configure args move controller to error', () {
      final controller = ModuleController(ConfigurableModule());

      expect(
        () => controller.configure('wrong_type'),
        throwsA(isA<ModuleLifecycleException>()),
      );
      expect(controller.currentStatus, equals(ModuleStatus.error));
      expect(controller.lastError, isA<ModuleLifecycleException>());
    });

    test(
      'configure after initialization has started throws lifecycle error',
      () async {
        final controller = ModuleController(ConfigurableModule());
        final registry = <ModuleRegistryKey, ModuleController>{};

        controller.configure(ConfigData('test_value'));
        await controller.initialize(registry);

        expect(
          () => controller.configure(ConfigData('another_value')),
          throwsA(isA<ModuleLifecycleException>()),
        );
        expect(controller.currentStatus, equals(ModuleStatus.loaded));
      },
    );
  });

  group('ModuleController dispose', () {
    test('dispose clears binder and updates status', () async {
      final module = LifecycleOrderModule();
      final controller = ModuleController(module);
      final registry = <ModuleRegistryKey, ModuleController>{};

      await controller.initialize(registry);
      await controller.dispose();

      expect(controller.currentStatus, equals(ModuleStatus.disposed));
    });

    test('dispose before initialize does not call module cleanup', () async {
      final module = SlowInitModule(Completer<void>());
      final controller = ModuleController(module);

      await controller.dispose();

      expect(controller.currentStatus, equals(ModuleStatus.disposed));
      expect(module.disposeCount, equals(0));
    });

    test('dispose waits for async module cleanup', () async {
      final allowDispose = Completer<void>();
      final module = AsyncDisposeModule(allowDispose);
      final controller = ModuleController(module);
      final registry = <ModuleRegistryKey, ModuleController>{};

      await controller.initialize(registry);

      final disposeFuture = controller.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentStatus, equals(ModuleStatus.disposed));
      expect(module.disposed, isFalse);

      allowDispose.complete();
      await disposeFuture;

      expect(module.disposed, isTrue);
    });

    test(
      'shared imports dispose only after all dependents release them',
      () async {
        SharedDisposableModule.resetCounts();
        final registry = <ModuleRegistryKey, ModuleController>{};
        final firstController = ModuleController(FirstSharedConsumerModule());
        final secondController = ModuleController(SecondSharedConsumerModule());

        await firstController.initialize(registry);
        await secondController.initialize(registry);

        expect(SharedDisposableModule.initCount, equals(1));

        await firstController.dispose();

        expect(SharedDisposableModule.disposeCount, equals(0));

        await secondController.dispose();

        expect(SharedDisposableModule.disposeCount, equals(1));
      },
    );

    test('disposed imported controllers are recreated from registry', () async {
      SharedDisposableModule.resetCounts();
      final registry = <ModuleRegistryKey, ModuleController>{};
      final firstController = ModuleController(FirstSharedConsumerModule());

      await firstController.initialize(registry);
      await firstController.dispose();

      expect(SharedDisposableModule.disposeCount, equals(1));

      final secondController = ModuleController(SecondSharedConsumerModule());
      await secondController.initialize(registry);

      expect(SharedDisposableModule.initCount, equals(2));
      expect(
        secondController.importedControllers.single.currentStatus,
        equals(ModuleStatus.loaded),
      );

      await secondController.dispose();
    });
  });

  group('ModuleController circular imports', () {
    test('throws on circular import A -> B -> A', () async {
      final controller = ModuleController(CircularA());
      final registry = <ModuleRegistryKey, ModuleController>{};

      await expectLater(
        () => controller.initialize(registry),
        throwsA(isA<Exception>()),
      );
    });
  });
}
