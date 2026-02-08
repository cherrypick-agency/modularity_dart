import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart' as injectable;
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:test/test.dart';

class _InternalDep {}

class _ExportedService {
  _ExportedService(this.dep);
  final _InternalDep dep;
}

class _ParentDep {}

class _NeedsParent {
  _NeedsParent(this.parent);
  final _ParentDep parent;
}

class _ImportDep {}

class _NeedsImport {
  _NeedsImport(this.dep);
  final _ImportDep dep;
}

GetIt _initInternal(
  GetIt getIt, {
  String? environment,
  injectable.EnvironmentFilter? environmentFilter,
}) {
  getIt.registerLazySingleton<_InternalDep>(() => _InternalDep());
  return getIt;
}

GetIt _initExports(
  GetIt getIt, {
  String? environment,
  injectable.EnvironmentFilter? environmentFilter,
}) {
  getIt.registerLazySingleton<_ExportedService>(
    () => _ExportedService(getIt.get<_InternalDep>()),
  );
  return getIt;
}

GetIt _initNeedsParent(
  GetIt getIt, {
  String? environment,
  injectable.EnvironmentFilter? environmentFilter,
}) {
  getIt.registerFactory<_NeedsParent>(
    () => _NeedsParent(getIt.get<_ParentDep>()),
  );
  return getIt;
}

GetIt _initNeedsImport(
  GetIt getIt, {
  String? environment,
  injectable.EnvironmentFilter? environmentFilter,
}) {
  getIt.registerFactory<_NeedsImport>(
    () => _NeedsImport(getIt.get<_ImportDep>()),
  );
  return getIt;
}

GetIt _initExportsNeedsParent(
  GetIt getIt, {
  String? environment,
  injectable.EnvironmentFilter? environmentFilter,
}) {
  getIt.registerLazySingleton<_NeedsParent>(
    () => _NeedsParent(getIt.get<_ParentDep>()),
  );
  return getIt;
}

void main() {
  group('BinderGetIt', () {
    test(
      'export factory can resolve private dependency via Binder fallback',
      () {
        final binder = GetItBinder();

        ModularityInjectableBridge.configureInternal(binder, _initInternal);
        ModularityInjectableBridge.configureExports(binder, _initExports);
        binder.sealPublicScope();

        final exported = binder.get<_ExportedService>();
        expect(exported.dep, isA<_InternalDep>());

        binder.dispose();
      },
    );

    test(
      'factory can resolve dependency from parent binder without manual parent()',
      () {
        final parentBinder = GetItBinder();
        parentBinder.registerLazySingleton<_ParentDep>(() => _ParentDep());

        final binder = GetItBinder(parent: parentBinder);
        ModularityInjectableBridge.configureInternal(binder, _initNeedsParent);

        final obj = binder.get<_NeedsParent>();
        expect(obj.parent, isA<_ParentDep>());

        binder.dispose();
        parentBinder.dispose();
      },
    );

    test(
      'factory can resolve dependency from imports (public) without manual wiring',
      () {
        final provider = GetItBinder();
        provider.enableExportMode();
        provider.registerLazySingleton<_ImportDep>(() => _ImportDep());
        provider.disableExportMode();
        provider.sealPublicScope();

        final consumer = GetItBinder(imports: [provider]);
        ModularityInjectableBridge.configureInternal(
          consumer,
          _initNeedsImport,
        );

        final obj = consumer.get<_NeedsImport>();
        expect(obj.dep, isA<_ImportDep>());

        consumer.dispose();
        provider.dispose();
      },
    );

    test(
      'exports container can resolve parent dependency without manual parent()',
      () {
        final parentBinder = GetItBinder();
        parentBinder.registerLazySingleton<_ParentDep>(() => _ParentDep());

        final binder = GetItBinder(parent: parentBinder);
        ModularityInjectableBridge.configureExports(
          binder,
          _initExportsNeedsParent,
        );
        binder.sealPublicScope();

        final obj = binder.get<_NeedsParent>();
        expect(obj.parent, isA<_ParentDep>());

        binder.dispose();
        parentBinder.dispose();
      },
    );

    test('isRegistered uses Binder.contains for unnamed lookups', () {
      final parentBinder = GetItBinder();
      parentBinder.registerLazySingleton<_ParentDep>(() => _ParentDep());

      final binder = GetItBinder(parent: parentBinder);
      final wrapped = BinderGetIt(
        primary: GetIt.asNewInstance(),
        binder: binder,
      );

      expect(wrapped.isRegistered<_ParentDep>(), isTrue);
      expect(wrapped.isRegistered<_InternalDep>(), isFalse);

      binder.dispose();
      parentBinder.dispose();
    });
  });
}
