import 'package:get_it/get_it.dart';
import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:modularity_get_it/modularity_get_it.dart';
import 'package:test/test.dart';

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

    test('preserve strategy keeps existing singleton instances', () {
      final binder = GetItBinder();
      binder.registerLazySingleton<String>(() => 'v1');
      final first = binder.get<String>();

      binder.runWithStrategy(RegistrationStrategy.preserveExisting, () {
        binder.registerLazySingleton<String>(() => 'v2');
      });

      final second = binder.get<String>();
      expect(second, same(first));
    });

    test('preserve strategy updates factory delegates', () {
      final binder = GetItBinder();
      binder.registerFactory<int>(() => 1);
      expect(binder.get<int>(), equals(1));

      binder.runWithStrategy(RegistrationStrategy.preserveExisting, () {
        binder.registerFactory<int>(() => 2);
      });

      expect(binder.get<int>(), equals(2));
    });

    group('export mode', () {
      test('registrations in export mode appear in containsPublic', () {
        final binder = GetItBinder();
        binder.enableExportMode();
        binder.registerSingleton<String>('exported');
        binder.disableExportMode();

        expect(binder.containsPublic(String), isTrue);
      });

      test(
        'registrations outside export mode do not appear in containsPublic',
        () {
          final binder = GetItBinder();
          binder.registerSingleton<String>('private');

          expect(binder.containsPublic(String), isFalse);
        },
      );

      test('tryGetPublic returns exported values', () {
        final binder = GetItBinder();
        binder.enableExportMode();
        binder.registerSingleton<String>('public_value');
        binder.disableExportMode();

        expect(binder.tryGetPublic<String>(), equals('public_value'));
      });

      test('tryGetPublic returns null for private registrations', () {
        final binder = GetItBinder();
        binder.registerSingleton<String>('private_value');

        expect(binder.tryGetPublic<String>(), isNull);
      });

      test('tryGetPublic returns null for unregistered type', () {
        final binder = GetItBinder();
        expect(binder.tryGetPublic<String>(), isNull);
      });
    });

    group('sealed scope', () {
      test('rejects new exports when sealed', () {
        final binder = GetItBinder();
        binder.enableExportMode();
        binder.sealPublicScope();

        expect(
          () => binder.registerSingleton<String>('should fail'),
          throwsA(isA<ModuleConfigurationException>()),
        );
      });

      test('accepts registrations in private mode even when sealed', () {
        final binder = GetItBinder();
        binder.enableExportMode();
        binder.sealPublicScope();
        binder.disableExportMode();

        // Private registrations should succeed even when public is sealed
        expect(
          () => binder.registerSingleton<String>('private ok'),
          returnsNormally,
        );
      });

      test('resetPublicScope allows new exports after sealing', () {
        final binder = GetItBinder();
        binder.enableExportMode();
        binder.sealPublicScope();

        // Sealed: should throw
        expect(
          () => binder.registerSingleton<String>('fail'),
          throwsA(isA<ModuleConfigurationException>()),
        );

        binder.resetPublicScope();

        // Unsealed: should work
        expect(() => binder.registerSingleton<String>('ok'), returnsNormally);
      });

      test('isPublicScopeSealed reflects seal state', () {
        final binder = GetItBinder();
        expect(binder.isPublicScopeSealed, isFalse);

        binder.sealPublicScope();
        expect(binder.isPublicScopeSealed, isTrue);

        binder.resetPublicScope();
        expect(binder.isPublicScopeSealed, isFalse);
      });

      test('isExportModeEnabled reflects export mode state', () {
        final binder = GetItBinder();
        expect(binder.isExportModeEnabled, isFalse);

        binder.enableExportMode();
        expect(binder.isExportModeEnabled, isTrue);

        binder.disableExportMode();
        expect(binder.isExportModeEnabled, isFalse);
      });
    });

    group('contains() checks imports with containsPublic', () {
      test('contains checks containsPublic on ExportableBinder imports', () {
        // Create an import binder and register a type in export mode
        final importBinder = GetItBinder();
        importBinder.enableExportMode();
        importBinder.registerSingleton<String>('exported');
        importBinder.disableExportMode();

        // Register a private-only type
        importBinder.registerSingleton<int>(42);

        final mainBinder = GetItBinder();
        mainBinder.addImports([importBinder]);

        // Exported type should be visible through contains
        expect(mainBinder.contains(String), isTrue);

        // Private type should NOT be visible through contains
        // because contains uses containsPublic for ExportableBinder imports
        expect(mainBinder.contains(int), isFalse);
      });

      test('contains returns true for locally registered types', () {
        final binder = GetItBinder();
        binder.registerSingleton<String>('local');

        expect(binder.contains(String), isTrue);
      });

      test('contains returns false for unregistered types', () {
        final binder = GetItBinder();
        expect(binder.contains(String), isFalse);
      });
    });

    group('parent scope lookups', () {
      test('parent() retrieves from parent scope', () {
        final parentBinder = GetItBinder();
        parentBinder.registerSingleton<String>('from_parent');

        final childBinder = GetItBinder(parentBinder);

        expect(childBinder.parent<String>(), equals('from_parent'));
      });

      test('parent() throws DependencyNotFoundException when not found', () {
        final parentBinder = GetItBinder();
        final childBinder = GetItBinder(parentBinder);

        expect(
          () => childBinder.parent<String>(),
          throwsA(isA<DependencyNotFoundException>()),
        );
      });

      test('tryParent() returns null when not found', () {
        final parentBinder = GetItBinder();
        final childBinder = GetItBinder(parentBinder);

        expect(childBinder.tryParent<String>(), isNull);
      });

      test('tryParent() returns value from parent', () {
        final parentBinder = GetItBinder();
        parentBinder.registerSingleton<String>('parent_value');

        final childBinder = GetItBinder(parentBinder);

        expect(childBinder.tryParent<String>(), equals('parent_value'));
      });

      test('contains checks parent scope', () {
        final parentBinder = GetItBinder();
        parentBinder.registerSingleton<String>('parent_value');

        final childBinder = GetItBinder(parentBinder);

        expect(childBinder.contains(String), isTrue);
      });
    });

    group('tryGet resolution order: local -> imports -> parent', () {
      test('local registration takes precedence over imports', () {
        final importBinder = GetItBinder();
        importBinder.enableExportMode();
        importBinder.registerSingleton<String>('from_import');
        importBinder.disableExportMode();

        final binder = GetItBinder();
        binder.addImports([importBinder]);
        binder.registerSingleton<String>('local');

        expect(binder.tryGet<String>(), equals('local'));
      });

      test('imports take precedence over parent', () {
        final parentBinder = GetItBinder();
        parentBinder.registerSingleton<String>('from_parent');

        final importBinder = GetItBinder();
        importBinder.enableExportMode();
        importBinder.registerSingleton<String>('from_import');
        importBinder.disableExportMode();

        final childBinder = GetItBinder(parentBinder);
        childBinder.addImports([importBinder]);

        expect(childBinder.tryGet<String>(), equals('from_import'));
      });

      test('falls back to parent when not in local or imports', () {
        final parentBinder = GetItBinder();
        parentBinder.registerSingleton<String>('from_parent');

        final childBinder = GetItBinder(parentBinder);

        expect(childBinder.tryGet<String>(), equals('from_parent'));
      });

      test('returns null when not found anywhere', () {
        final parentBinder = GetItBinder();
        final childBinder = GetItBinder(parentBinder);

        expect(childBinder.tryGet<String>(), isNull);
      });

      test('get() throws DependencyNotFoundException when not found', () {
        final binder = GetItBinder();

        expect(
          () => binder.get<String>(),
          throwsA(isA<DependencyNotFoundException>()),
        );
      });
    });

    group('tryGetPublic only returns exported types', () {
      test('tryGetPublic returns null for privately registered type', () {
        final binder = GetItBinder();
        // Register without export mode
        binder.registerSingleton<String>('private');

        expect(binder.tryGetPublic<String>(), isNull);
      });

      test('tryGetPublic returns value for exported type', () {
        final binder = GetItBinder();
        binder.enableExportMode();
        binder.registerSingleton<String>('public');
        binder.disableExportMode();

        expect(binder.tryGetPublic<String>(), equals('public'));
      });

      test('containsPublic returns false for private type', () {
        final binder = GetItBinder();
        binder.registerSingleton<String>('private');

        expect(binder.containsPublic(String), isFalse);
      });

      test('containsPublic returns true for exported type', () {
        final binder = GetItBinder();
        binder.enableExportMode();
        binder.registerSingleton<String>('public');
        binder.disableExportMode();

        expect(binder.containsPublic(String), isTrue);
      });
    });

    group('dispose/reset clears state', () {
      test('dispose clears all registrations', () async {
        final binder = GetItBinder();
        binder.registerSingleton<String>('value');
        binder.enableExportMode();
        binder.registerSingleton<int>(42);
        binder.disableExportMode();

        await binder.dispose();

        expect(binder.tryGet<String>(), isNull);
        expect(binder.tryGet<int>(), isNull);
      });

      test('dispose clears exported types tracking', () async {
        final binder = GetItBinder();
        binder.enableExportMode();
        binder.registerSingleton<String>('public');
        binder.disableExportMode();

        expect(binder.containsPublic(String), isTrue);

        await binder.dispose();

        expect(binder.containsPublic(String), isFalse);
      });

      test('reset clears factory delegates', () async {
        final binder = GetItBinder();
        binder.registerFactory<int>(() => 1);
        expect(binder.get<int>(), equals(1));

        await binder.reset();

        expect(binder.tryGet<int>(), isNull);
      });

      test('reset clears lazy singleton delegates', () async {
        final binder = GetItBinder();
        binder.registerLazySingleton<String>(() => 'lazy');
        expect(binder.get<String>(), equals('lazy'));

        await binder.reset();

        expect(binder.tryGet<String>(), isNull);
      });
    });

    group('DisposableBinder interface compliance', () {
      test('implements DisposableBinder', () {
        final binder = GetItBinder();
        expect(binder, isA<DisposableBinder>());
      });

      test('dispose() is callable and returns Future', () async {
        final binder = GetItBinder();
        binder.registerSingleton<String>('test');

        // dispose should complete without error
        await expectLater(binder.dispose(), completes);
      });

      test('implements ExportableBinder', () {
        final binder = GetItBinder();
        expect(binder, isA<ExportableBinder>());
      });

      test('implements RegistrationAwareBinder', () {
        final binder = GetItBinder();
        expect(binder, isA<RegistrationAwareBinder>());
      });
    });

    group('runWithStrategy', () {
      test('default strategy is replace', () {
        final binder = GetItBinder();
        expect(
          binder.registrationStrategy,
          equals(RegistrationStrategy.replace),
        );
      });

      test('runWithStrategy temporarily changes strategy', () {
        final binder = GetItBinder();

        binder.runWithStrategy(RegistrationStrategy.preserveExisting, () {
          expect(
            binder.registrationStrategy,
            equals(RegistrationStrategy.preserveExisting),
          );
        });

        // Strategy restored after runWithStrategy completes
        expect(
          binder.registrationStrategy,
          equals(RegistrationStrategy.replace),
        );
      });

      test('runWithStrategy restores strategy on exception', () {
        final binder = GetItBinder();

        try {
          binder.runWithStrategy(RegistrationStrategy.preserveExisting, () {
            throw Exception('boom');
          });
        } catch (_) {}

        expect(
          binder.registrationStrategy,
          equals(RegistrationStrategy.replace),
        );
      });

      test('runWithStrategy returns body result', () {
        final binder = GetItBinder();

        final result = binder.runWithStrategy(
          RegistrationStrategy.preserveExisting,
          () => 42,
        );

        expect(result, equals(42));
      });

      test('nested runWithStrategy scopes work correctly', () {
        final binder = GetItBinder();

        binder.runWithStrategy(RegistrationStrategy.preserveExisting, () {
          expect(
            binder.registrationStrategy,
            equals(RegistrationStrategy.preserveExisting),
          );

          binder.runWithStrategy(RegistrationStrategy.replace, () {
            expect(
              binder.registrationStrategy,
              equals(RegistrationStrategy.replace),
            );
          });

          // Inner scope ended, back to preserve
          expect(
            binder.registrationStrategy,
            equals(RegistrationStrategy.preserveExisting),
          );
        });

        // Outer scope ended, back to replace
        expect(
          binder.registrationStrategy,
          equals(RegistrationStrategy.replace),
        );
      });
    });

    group('registration types', () {
      test('registerLazySingleton creates instance lazily', () {
        var created = false;
        final binder = GetItBinder();
        binder.registerLazySingleton<String>(() {
          created = true;
          return 'lazy';
        });

        expect(created, isFalse);
        final value = binder.get<String>();
        expect(created, isTrue);
        expect(value, equals('lazy'));
      });

      test('registerLazySingleton returns same instance on repeated get', () {
        final binder = GetItBinder();
        var count = 0;
        binder.registerLazySingleton<String>(() {
          count++;
          return 'lazy_$count';
        });

        final first = binder.get<String>();
        final second = binder.get<String>();
        expect(first, same(second));
        expect(count, equals(1));
      });

      test('registerFactory returns new instance each time', () {
        final binder = GetItBinder();
        var count = 0;
        binder.registerFactory<int>(() => ++count);

        expect(binder.get<int>(), equals(1));
        expect(binder.get<int>(), equals(2));
        expect(binder.get<int>(), equals(3));
      });

      test('registerSingleton stores exact instance', () {
        final binder = GetItBinder();
        final instance = StringBuffer('eager');
        binder.registerSingleton<StringBuffer>(instance);

        expect(binder.get<StringBuffer>(), same(instance));
      });

      test('singleton() is alias for registerLazySingleton', () {
        final binder = GetItBinder();
        binder.singleton<String>(() => 'via_alias');
        expect(binder.get<String>(), equals('via_alias'));
      });

      test('factory() is alias for registerFactory', () {
        final binder = GetItBinder();
        var count = 0;
        binder.factory<int>(() => ++count);
        expect(binder.get<int>(), equals(1));
        expect(binder.get<int>(), equals(2));
      });
    });

    group('addImports', () {
      test('addImports adds binders to search chain', () {
        final importBinder = GetItBinder();
        importBinder.enableExportMode();
        importBinder.registerSingleton<String>('imported');
        importBinder.disableExportMode();

        final binder = GetItBinder();
        binder.addImports([importBinder]);

        expect(binder.get<String>(), equals('imported'));
      });

      test('addImports can be called multiple times', () {
        final import1 = GetItBinder();
        import1.enableExportMode();
        import1.registerSingleton<String>('from_import1');
        import1.disableExportMode();

        final import2 = GetItBinder();
        import2.enableExportMode();
        import2.registerSingleton<int>(42);
        import2.disableExportMode();

        final binder = GetItBinder();
        binder.addImports([import1]);
        binder.addImports([import2]);

        expect(binder.get<String>(), equals('from_import1'));
        expect(binder.get<int>(), equals(42));
      });
    });

    group('GetItBinderFactory', () {
      test('creates isolated binders by default', () {
        const factory = GetItBinderFactory();
        final binder = factory.create() as GetItBinder;

        binder.registerSingleton<String>('isolated');

        expect(GetIt.instance.isRegistered<String>(), isFalse);
      });

      test('creates global binders when configured', () {
        const factory = GetItBinderFactory(useGlobalInstance: true);
        final binder = factory.create() as GetItBinder;

        binder.registerSingleton<String>('global');

        expect(GetIt.instance.isRegistered<String>(), isTrue);
      });

      test('accepts parent parameter', () {
        final parentBinder = GetItBinder();
        parentBinder.registerSingleton<String>('parent_value');

        const factory = GetItBinderFactory();
        final childBinder = factory.create(parentBinder) as GetItBinder;

        expect(childBinder.tryParent<String>(), equals('parent_value'));
      });

      test('implements BinderFactory', () {
        const factory = GetItBinderFactory();
        expect(factory, isA<BinderFactory>());
      });
    });
  });
}
