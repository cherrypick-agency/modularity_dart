import 'package:modularity_injectable_adapter/modularity_injectable_adapter.dart';
import 'package:test/test.dart';

class _InternalService {}

class _ExportedService {}

class _AnotherExport {}

void main() {
  group('GetItBinder', () {
    late GetItBinder provider;
    late GetItBinder consumer;

    setUp(() {
      provider = GetItBinder();
      consumer = GetItBinder(imports: [provider]);
    });

    tearDown(() {
      provider.dispose();
      consumer.dispose();
    });

    test('private registrations never leak to imports', () {
      provider
          .registerLazySingleton<_InternalService>(() => _InternalService());

      expect(provider.get<_InternalService>(), isA<_InternalService>());
      expect(consumer.tryGet<_InternalService>(), isNull);
    });

    test('public registrations propagate through imports', () {
      provider.enableExportMode();
      provider
          .registerLazySingleton<_ExportedService>(() => _ExportedService());
      provider.disableExportMode();
      provider.sealPublicScope();

      expect(consumer.get<_ExportedService>(), isA<_ExportedService>());
    });

    test('duplicate exports throw', () {
      provider.enableExportMode();
      provider
          .registerLazySingleton<_ExportedService>(() => _ExportedService());

      expect(
        () => provider
            .registerLazySingleton<_ExportedService>(() => _ExportedService()),
        throwsStateError,
      );
    });

    test('sealed public scope rejects new exports until reset', () {
      provider.enableExportMode();
      provider
          .registerLazySingleton<_ExportedService>(() => _ExportedService());
      provider.disableExportMode();
      provider.sealPublicScope();

      provider.enableExportMode();
      expect(
        () => provider
            .registerLazySingleton<_AnotherExport>(() => _AnotherExport()),
        throwsStateError,
      );

      provider.resetPublicScope();
      provider.registerLazySingleton<_AnotherExport>(() => _AnotherExport());
    });
  });
}
