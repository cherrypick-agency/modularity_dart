import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart' as injectable
    show EnvironmentFilter;
import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:modularity_injectable_adapter/modularity_injectable_adapter.dart';
import 'package:test/test.dart';

class _PrivateService {}

class _ExportedService {}

class _NotGetItBinder implements Binder {
  @override
  void addImports(List<Binder> binders) {}

  @override
  bool contains(Type type) => false;

  @override
  void factory<T extends Object>(T Function() factory) {}

  @override
  T get<T extends Object>() => throw UnimplementedError();

  @override
  void registerFactory<T extends Object>(T Function() factory) {}

  @override
  void registerLazySingleton<T extends Object>(T Function() factory) {}

  @override
  void registerSingleton<T extends Object>(T instance) {}

  @override
  void singleton<T extends Object>(T Function() factory) {}

  @override
  T? tryGet<T extends Object>() => null;

  @override
  T parent<T extends Object>() => throw UnimplementedError();

  @override
  T? tryParent<T extends Object>() => null;
}

GetIt _fakeInit(
  GetIt getIt, {
  String? environment,
  injectable.EnvironmentFilter? environmentFilter,
}) {
  void register<T extends Object>(
    T Function() builder, {
    Set<String> envs = const {},
  }) {
    final shouldRegister =
        environmentFilter == null || environmentFilter.canRegister(envs);
    if (shouldRegister) {
      getIt.registerSingleton<T>(builder());
    }
  }

  register<_PrivateService>(() => _PrivateService());
  register<_ExportedService>(
    () => _ExportedService(),
    envs: {modularityExportEnv.name},
  );

  return getIt;
}

void main() {
  group('ModularityInjectableBridge', () {
    late GetItBinder binder;

    setUp(() {
      binder = GetItBinder();
    });

    tearDown(() {
      binder.dispose();
    });

    test('configureInternal registers all dependencies privately', () {
      ModularityInjectableBridge.configureInternal(binder, _fakeInit);

      expect(binder.get<_PrivateService>(), isA<_PrivateService>());
      // Exported type is also available privately, but not yet exposed.
      expect(binder.get<_ExportedService>(), isA<_ExportedService>());
      expect(binder.tryGetPublic<_ExportedService>(), isNull);
    });

    test('configureExports registers only annotated public dependencies', () {
      ModularityInjectableBridge.configureExports(binder, _fakeInit);

      expect(binder.tryGetPublic<_ExportedService>(), isA<_ExportedService>());
      expect(binder.tryGetPublic<_PrivateService>(), isNull);
    });

    test('throws when binder is not backed by GetIt', () {
      final wrongBinder = _NotGetItBinder();

      expect(
        () => ModularityInjectableBridge.configureInternal(
          wrongBinder,
          _fakeInit,
        ),
        throwsStateError,
      );
    });
  });
}
