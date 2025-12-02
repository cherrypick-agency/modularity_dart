import 'package:modularity_core/modularity_core.dart';
import 'package:test/test.dart';

class _InternalService {}

class _PublicService {}

class _AnotherExport {}

class _SharedService {}

class _FactoryService {
  static int instanceCount = 0;
  _FactoryService() {
    instanceCount++;
  }
}

class _SingletonService {
  static int instanceCount = 0;
  _SingletonService() {
    instanceCount++;
  }
}

class _EagerService {}

class _Level1Service {}

class _Level2Service {}

class _Level3Service {}

class _ImportA {}

class _ImportB {}

class _UnregisteredService {}

void main() {
  group('SimpleBinder scopes', () {
    late SimpleBinder binder;

    setUp(() {
      binder = SimpleBinder();
      _FactoryService.instanceCount = 0;
      _SingletonService.instanceCount = 0;
    });

    test('private registrations remain invisible to imports', () {
      final provider = SimpleBinder();
      provider
          .registerLazySingleton<_InternalService>(() => _InternalService());

      final consumer = SimpleBinder();
      consumer.addImports([provider]);

      expect(consumer.tryGet<_InternalService>(), isNull);
    });

    test('public registrations propagate through imports', () {
      final provider = SimpleBinder();
      provider.enableExportMode();
      provider.registerLazySingleton<_PublicService>(() => _PublicService());
      provider.disableExportMode();
      provider.sealPublicScope();

      final consumer = SimpleBinder();
      consumer.addImports([provider]);

      expect(consumer.get<_PublicService>(), isA<_PublicService>());
    });

    test('duplicate exports throw descriptive error', () {
      binder.enableExportMode();
      binder.registerLazySingleton<_PublicService>(() => _PublicService());

      expect(
        () => binder
            .registerLazySingleton<_PublicService>(() => _PublicService()),
        throwsStateError,
      );
    });

    test('sealed public scope rejects late exports until reset', () {
      binder.enableExportMode();
      binder.registerLazySingleton<_PublicService>(() => _PublicService());
      binder.disableExportMode();
      binder.sealPublicScope();

      binder.enableExportMode();
      expect(
        () => binder
            .registerLazySingleton<_AnotherExport>(() => _AnotherExport()),
        throwsStateError,
      );

      binder.resetPublicScope();
      binder.registerLazySingleton<_AnotherExport>(() => _AnotherExport());
    });

    test('parent scope lookup works', () {
      final parent = SimpleBinder();
      parent.registerLazySingleton<_SharedService>(() => _SharedService());

      final child = SimpleBinder(parent: parent);

      expect(child.parent<_SharedService>(), isA<_SharedService>());
      expect(child.tryParent<_SharedService>(), isA<_SharedService>());
    });

    test('debugGraph contains both private and public keys', () {
      binder.registerLazySingleton<_InternalService>(() => _InternalService());
      binder.enableExportMode();
      binder.registerLazySingleton<_PublicService>(() => _PublicService());
      binder.disableExportMode();

      final graph = binder.debugGraph();

      expect(graph, contains('_InternalService'));
      expect(graph, contains('_PublicService'));
    });

    test('factory registration creates new instance each call', () {
      binder.registerFactory<_FactoryService>(() => _FactoryService());

      final first = binder.get<_FactoryService>();
      final second = binder.get<_FactoryService>();

      expect(first, isNot(same(second)));
      expect(_FactoryService.instanceCount, equals(2));
    });

    test('singleton caches instance after first call', () {
      binder
          .registerLazySingleton<_SingletonService>(() => _SingletonService());

      final first = binder.get<_SingletonService>();
      final second = binder.get<_SingletonService>();

      expect(first, same(second));
      expect(_SingletonService.instanceCount, equals(1));
    });

    test('registerSingleton provides eager instance immediately', () {
      final eager = _EagerService();
      binder.registerSingleton<_EagerService>(eager);

      final resolved = binder.get<_EagerService>();

      expect(resolved, same(eager));
    });

    test('import chain 3-level: consumer -> mid -> base', () {
      final base = SimpleBinder();
      base.enableExportMode();
      base.registerLazySingleton<_Level1Service>(() => _Level1Service());
      base.disableExportMode();
      base.sealPublicScope();

      final mid = SimpleBinder(imports: [base]);
      mid.enableExportMode();
      mid.registerLazySingleton<_Level2Service>(() => _Level2Service());
      mid.disableExportMode();
      mid.sealPublicScope();

      final consumer = SimpleBinder(imports: [mid]);
      consumer.registerLazySingleton<_Level3Service>(() => _Level3Service());

      expect(consumer.get<_Level2Service>(), isA<_Level2Service>());
      expect(consumer.tryGet<_Level1Service>(), isNull,
          reason: 'Level1 is not re-exported by mid');
    });

    test('multiple imports only expose public deps', () {
      final providerA = SimpleBinder();
      providerA
          .registerLazySingleton<_InternalService>(() => _InternalService());
      providerA.enableExportMode();
      providerA.registerLazySingleton<_ImportA>(() => _ImportA());
      providerA.disableExportMode();
      providerA.sealPublicScope();

      final providerB = SimpleBinder();
      providerB.enableExportMode();
      providerB.registerLazySingleton<_ImportB>(() => _ImportB());
      providerB.disableExportMode();
      providerB.sealPublicScope();

      final consumer = SimpleBinder(imports: [providerA, providerB]);

      expect(consumer.get<_ImportA>(), isA<_ImportA>());
      expect(consumer.get<_ImportB>(), isA<_ImportB>());
      expect(consumer.tryGet<_InternalService>(), isNull);
    });

    test('tryGet returns null for unregistered types', () {
      expect(binder.tryGet<_UnregisteredService>(), isNull);
    });

    test('get throws descriptive error with available keys', () {
      binder.registerLazySingleton<_InternalService>(() => _InternalService());

      expect(
        () => binder.get<_UnregisteredService>(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('_UnregisteredService'),
              contains('_InternalService'),
            ),
          ),
        ),
      );
    });

    test('resolution priority: local > imports > parent', () {
      final parentBinder = SimpleBinder();
      parentBinder
          .registerLazySingleton<_SharedService>(() => _SharedService());

      final importBinder = SimpleBinder();
      importBinder.enableExportMode();
      importBinder
          .registerLazySingleton<_SharedService>(() => _SharedService());
      importBinder.disableExportMode();
      importBinder.sealPublicScope();

      final localBinder =
          SimpleBinder(parent: parentBinder, imports: [importBinder]);
      final localInstance = _SharedService();
      localBinder.registerSingleton<_SharedService>(localInstance);

      expect(localBinder.get<_SharedService>(), same(localInstance));
    });

    test('debugGraph with imports includes nested binders', () {
      final provider = SimpleBinder();
      provider.enableExportMode();
      provider.registerLazySingleton<_PublicService>(() => _PublicService());
      provider.disableExportMode();

      final consumer = SimpleBinder(imports: [provider]);
      consumer
          .registerLazySingleton<_InternalService>(() => _InternalService());

      final graph = consumer.debugGraph(includeImports: true);

      expect(graph, contains('_InternalService'));
      expect(graph, contains('_PublicService'));
      expect(graph, contains('Imports:'));
    });
  });
}
