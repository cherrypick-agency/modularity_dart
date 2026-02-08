import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:test/test.dart';

class _InternalService {}

class _ExportedService {}

class _AnotherExport {}

class _FactoryService {
  _FactoryService() {
    instanceCount++;
  }
  static int instanceCount = 0;
}

class _SingletonService {
  _SingletonService() {
    instanceCount++;
  }
  static int instanceCount = 0;
}

class _EagerService {}

class _ParentService {}

class _SharedService {}

class _ImportA {}

class _ImportB {}

void main() {
  group('GetItBinder', () {
    late GetItBinder provider;
    late GetItBinder consumer;

    setUp(() {
      provider = GetItBinder();
      consumer = GetItBinder(imports: [provider]);
      _FactoryService.instanceCount = 0;
      _SingletonService.instanceCount = 0;
    });

    tearDown(() {
      provider.dispose();
      consumer.dispose();
    });

    test('private registrations never leak to imports', () {
      provider.registerLazySingleton<_InternalService>(
        () => _InternalService(),
      );

      expect(provider.get<_InternalService>(), isA<_InternalService>());
      expect(consumer.tryGet<_InternalService>(), isNull);
    });

    test('public registrations propagate through imports', () {
      provider.enableExportMode();
      provider.registerLazySingleton<_ExportedService>(
        () => _ExportedService(),
      );
      provider.disableExportMode();
      provider.sealPublicScope();

      expect(consumer.get<_ExportedService>(), isA<_ExportedService>());
    });

    test('duplicate exports throw', () {
      provider.enableExportMode();
      provider.registerLazySingleton<_ExportedService>(
        () => _ExportedService(),
      );

      expect(
        () => provider.registerLazySingleton<_ExportedService>(
          () => _ExportedService(),
        ),
        throwsA(isA<ModuleConfigurationException>()),
      );
    });

    test('sealed public scope rejects new exports until reset', () {
      provider.enableExportMode();
      provider.registerLazySingleton<_ExportedService>(
        () => _ExportedService(),
      );
      provider.disableExportMode();
      provider.sealPublicScope();

      provider.enableExportMode();
      expect(
        () => provider.registerLazySingleton<_AnotherExport>(
          () => _AnotherExport(),
        ),
        throwsA(isA<ModuleConfigurationException>()),
      );

      provider.resetPublicScope();
      provider.registerLazySingleton<_AnotherExport>(() => _AnotherExport());
    });

    test('factory registration creates new instance each call', () {
      provider.registerFactory<_FactoryService>(() => _FactoryService());

      final first = provider.get<_FactoryService>();
      final second = provider.get<_FactoryService>();

      expect(first, isNot(same(second)));
      expect(_FactoryService.instanceCount, equals(2));
    });

    test('singleton caches instance after first call', () {
      provider.registerLazySingleton<_SingletonService>(
        () => _SingletonService(),
      );

      final first = provider.get<_SingletonService>();
      final second = provider.get<_SingletonService>();

      expect(first, same(second));
      expect(_SingletonService.instanceCount, equals(1));
    });

    test('registerSingleton provides eager instance immediately', () {
      final eager = _EagerService();
      provider.registerSingleton<_EagerService>(eager);

      final resolved = provider.get<_EagerService>();

      expect(resolved, same(eager));
    });

    test('parent scope lookup works', () {
      final parentBinder = GetItBinder();
      parentBinder.registerLazySingleton<_ParentService>(
        () => _ParentService(),
      );

      final childBinder = GetItBinder(parent: parentBinder);

      expect(childBinder.parent<_ParentService>(), isA<_ParentService>());
      expect(childBinder.tryParent<_ParentService>(), isA<_ParentService>());

      parentBinder.dispose();
      childBinder.dispose();
    });

    test('resolution priority: local > imports > parent', () {
      final parentBinder = GetItBinder();
      parentBinder.registerLazySingleton<_SharedService>(
        () => _SharedService(),
      );

      final importBinder = GetItBinder();
      importBinder.enableExportMode();
      importBinder.registerLazySingleton<_SharedService>(
        () => _SharedService(),
      );
      importBinder.disableExportMode();
      importBinder.sealPublicScope();

      final localBinder = GetItBinder(
        parent: parentBinder,
        imports: [importBinder],
      );
      final localInstance = _SharedService();
      localBinder.registerSingleton<_SharedService>(localInstance);

      expect(localBinder.get<_SharedService>(), same(localInstance));

      parentBinder.dispose();
      importBinder.dispose();
      localBinder.dispose();
    });

    test('debugGraph contains private and public types', () {
      provider.registerLazySingleton<_InternalService>(
        () => _InternalService(),
      );
      provider.enableExportMode();
      provider.registerLazySingleton<_ExportedService>(
        () => _ExportedService(),
      );
      provider.disableExportMode();

      final graph = provider.debugGraph();

      expect(graph, contains('_InternalService'));
      expect(graph, contains('_ExportedService'));
      expect(graph, contains('Private:'));
      expect(graph, contains('Public:'));
    });

    test('debugGraph with imports includes nested binders', () {
      provider.enableExportMode();
      provider.registerLazySingleton<_ExportedService>(
        () => _ExportedService(),
      );
      provider.disableExportMode();

      consumer.registerLazySingleton<_InternalService>(
        () => _InternalService(),
      );

      final graph = consumer.debugGraph(includeImports: true);

      expect(graph, contains('_InternalService'));
      expect(graph, contains('Imports:'));
      expect(graph, contains('_ExportedService'));
    });

    test('dispose clears both scopes', () async {
      provider.registerLazySingleton<_InternalService>(
        () => _InternalService(),
      );
      provider.enableExportMode();
      provider.registerLazySingleton<_ExportedService>(
        () => _ExportedService(),
      );
      provider.disableExportMode();

      await provider.dispose();

      expect(provider.tryGet<_InternalService>(), isNull);
      expect(provider.tryGetPublic<_ExportedService>(), isNull);
    });

    test('multiple imports from different providers', () {
      final providerA = GetItBinder();
      providerA.enableExportMode();
      providerA.registerLazySingleton<_ImportA>(() => _ImportA());
      providerA.disableExportMode();
      providerA.sealPublicScope();

      final providerB = GetItBinder();
      providerB.enableExportMode();
      providerB.registerLazySingleton<_ImportB>(() => _ImportB());
      providerB.disableExportMode();
      providerB.sealPublicScope();

      final multiConsumer = GetItBinder(imports: [providerA, providerB]);

      expect(multiConsumer.get<_ImportA>(), isA<_ImportA>());
      expect(multiConsumer.get<_ImportB>(), isA<_ImportB>());

      providerA.dispose();
      providerB.dispose();
      multiConsumer.dispose();
    });
  });
}
