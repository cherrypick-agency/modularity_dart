import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart'
    as injectable
    show EnvironmentFilter;
import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:test/test.dart';

class _PrivateService {}

class _ExportedService {}

class _ExportedServiceA {}

class _ExportedServiceB {}

class _DependencyService {}

class _ChainedExport {
  _ChainedExport(this.dependency);
  final _DependencyService dependency;
}

class _NotGetItBinder implements Binder {
  @override
  void addImports(List<Binder> binders) {}

  @override
  bool contains(Type type) => false;

  @override
  T get<T extends Object>() => throw UnimplementedError();

  @override
  void registerFactory<T extends Object>(T Function() factory) {}

  @override
  void registerLazySingleton<T extends Object>(T Function() factory) {}

  @override
  void registerSingleton<T extends Object>(T instance) {}

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

GetIt _multiExportInit(
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
  register<_ExportedServiceA>(
    () => _ExportedServiceA(),
    envs: {modularityExportEnv.name},
  );
  register<_ExportedServiceB>(
    () => _ExportedServiceB(),
    envs: {modularityExportEnv.name},
  );

  return getIt;
}

GetIt _mixedEnvInit(
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
  register<_ExportedServiceA>(
    () => _ExportedServiceA(),
    envs: {modularityExportEnv.name},
  );
  register<_ExportedServiceB>(() => _ExportedServiceB(), envs: {'other_env'});

  return getIt;
}

GetIt _chainedDepsInit(
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

  register<_DependencyService>(() => _DependencyService());
  register<_ChainedExport>(
    () => _ChainedExport(getIt.get<_DependencyService>()),
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
        throwsA(isA<ModuleConfigurationException>()),
      );
    });

    test('multiple export-annotated types all appear in public scope', () {
      ModularityInjectableBridge.configureExports(binder, _multiExportInit);

      expect(
        binder.tryGetPublic<_ExportedServiceA>(),
        isA<_ExportedServiceA>(),
      );
      expect(
        binder.tryGetPublic<_ExportedServiceB>(),
        isA<_ExportedServiceB>(),
      );
      expect(binder.tryGetPublic<_PrivateService>(), isNull);
    });

    test('mixed annotations: only modularityExportEnv goes to public', () {
      ModularityInjectableBridge.configureExports(binder, _mixedEnvInit);

      expect(
        binder.tryGetPublic<_ExportedServiceA>(),
        isA<_ExportedServiceA>(),
      );
      expect(binder.tryGetPublic<_ExportedServiceB>(), isNull);
      expect(binder.tryGetPublic<_PrivateService>(), isNull);
    });

    test('chained dependencies: exported type depends on private type', () {
      ModularityInjectableBridge.configureInternal(binder, _chainedDepsInit);

      final chained = binder.get<_ChainedExport>();
      expect(chained.dependency, isA<_DependencyService>());
    });
  });
}
