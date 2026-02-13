# Testing Modules

Test Modularity modules at three levels: pure Dart unit tests with `testModule()`, Flutter widget tests with `ModuleScope`, and manual `ModuleController` tests for lifecycle verification.

## Unit Testing (Pure Dart)

The `modularity_test` package provides `testModule()` -- it runs the full module lifecycle (resolve imports, binds, overrides, exports, onInit) and gives you a `TestBinder` that records all registrations and resolutions. The controller is automatically disposed after the body runs.

```yaml
dev_dependencies:
  modularity_test:
    path: ../packages/modularity_test
  test: ^1.25.0
```

```dart
import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_test/modularity_test.dart';
import 'package:test/test.dart';

class AuthModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<ApiClient>(() => ApiClient());
    binder.registerFactory<AuthRepository>(
      () => AuthRepository(binder.get<ApiClient>()),
    );
  }
}

test('AuthModule registers expected dependencies', () async {
  await testModule(AuthModule(), (module, binder) {
    expect(binder.hasSingleton<ApiClient>(), isTrue);
    expect(binder.hasFactory<AuthRepository>(), isTrue);

    final repo = binder.get<AuthRepository>();
    expect(repo, isA<AuthRepository>());
    expect(binder.wasResolved<AuthRepository>(), isTrue);
  });
});
```

### TestBinder API

| Method | Description |
|--------|-------------|
| `hasSingleton<T>()` | Was `T` registered via `registerLazySingleton`? |
| `hasFactory<T>()` | Was `T` registered via `registerFactory`? |
| `hasInstance<T>()` | Was `T` registered via `registerSingleton` (eager)? |
| `wasResolved<T>()` | Was `T` retrieved via `get` or `tryGet`? |
| `registeredSingletons` | All types registered as lazy singletons |
| `registeredFactories` | All types registered as factories |
| `registeredInstances` | All types registered as eager instances |
| `resolvedTypes` | All types that were resolved |

## Widget Testing

Wrap widgets in `ModularityRoot` + `ModuleScope` to test the full integration:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

testWidgets('ProfilePage shows user name', (tester) async {
  await tester.pumpWidget(
    ModularityRoot(
      child: MaterialApp(
        home: ModuleScope<ProfileModule>(
          module: ProfileModule(),
          overrides: (binder) {
            binder.registerLazySingleton<UserService>(
              () => FakeUserService(),
            );
          },
          child: const ProfilePage(),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('Test User'), findsOneWidget);
});
```

## Dependency Overrides

### Simple Overrides

Pass `overrides` to `testModule()` to replace real implementations with fakes:

```dart
test('override HttpClient with fake', () async {
  await testModule(
    NetworkModule(),
    overrides: (binder) {
      binder.registerSingleton<HttpClient>(FakeHttpClient());
    },
    (module, binder) {
      expect(binder.get<HttpClient>(), isA<FakeHttpClient>());
    },
  );
});
```

### ModuleOverrideScope

Use `overrideScope` when you need to override bindings inside **imported** modules. It lets you target specific child modules without affecting the rest of the dependency tree.

```dart
test('override imported module bindings', () async {
  await testModule(
    AppModule(),
    overrideScope: ModuleOverrideScope(
      children: {
        DataModule: ModuleOverrideScope(
          selfOverrides: (binder) {
            binder.registerLazySingleton<DatabaseService>(
              () => FakeDatabaseService(),
            );
          },
        ),
      },
    ),
    (module, binder) {
      expect(binder.get<DatabaseService>().name, equals('fake'));
    },
  );
});
```

Override scopes work the same way in widget tests:

```dart
testWidgets('override imported module in widget tree', (tester) async {
  await tester.pumpWidget(
    ModularityRoot(
      child: MaterialApp(
        home: ModuleScope<AppModule>(
          module: AppModule(),
          overrideScope: ModuleOverrideScope(
            children: {
              AuthModule: ModuleOverrideScope(
                selfOverrides: (binder) {
                  binder.registerLazySingleton<AuthService>(
                    () => FakeAuthService(),
                  );
                },
              ),
            },
          ),
          child: const AppPage(),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('Logged in as: test-user'), findsOneWidget);
});
```

For details on override timing and composition, see [Dependency Overrides](./dependency-overrides.md).

## Testing Async Initialization

`testModule()` awaits the full lifecycle including `onInit()`:

```dart
class CacheModule extends Module {
  bool initialized = false;

  @override
  void binds(Binder i) {
    i.registerLazySingleton<CacheService>(() => CacheService());
  }

  @override
  Future<void> onInit() async {
    await Future.delayed(const Duration(milliseconds: 100));
    initialized = true;
  }
}

test('onInit completes before test body', () async {
  await testModule(CacheModule(), (module, binder) {
    expect(module.initialized, isTrue);
  });
});
```

## Testing Error States

### Circular dependency detection

```dart
test('circular imports throw CircularDependencyException', () async {
  final controller = ModuleController(ModuleA());

  await expectLater(
    () => controller.initialize(<ModuleRegistryKey, ModuleController>{}),
    throwsA(isA<CircularDependencyException>()),
  );
});
```

### Missing expects validation

```dart
test('missing expects throw ModuleConfigurationException', () async {
  final controller = ModuleController(StrictModule());

  await expectLater(
    () => controller.initialize(<ModuleRegistryKey, ModuleController>{}),
    throwsA(isA<ModuleConfigurationException>()),
  );
});
```

### Error recovery in widgets

```dart
testWidgets('retry recovers from init failure', (tester) async {
  FlakyModule.attempts = 0;

  await tester.pumpWidget(
    ModularityRoot(
      child: MaterialApp(
        home: ModuleScope<FlakyModule>(
          module: FlakyModule(),
          child: const Text('Success'),
        ),
      ),
    ),
  );

  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('Module Init Failed'), findsOneWidget);

  await tester.tap(find.text('Retry'));
  await tester.pumpAndSettle();
  expect(find.text('Success'), findsOneWidget);
});
```

## Mocking

Modularity works with any mocking library. Use `mocktail` or `mockito` to create fakes and inject them via overrides.

### With mocktail

```dart
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

test('module uses mocked auth service', () async {
  final mockAuth = MockAuthService();
  when(() => mockAuth.currentUser).thenReturn(User(name: 'Test'));

  await testModule(
    ProfileModule(),
    overrides: (binder) {
      binder.registerSingleton<AuthService>(mockAuth);
    },
    (module, binder) {
      final profile = binder.get<ProfileService>();
      expect(profile.userName, equals('Test'));
      verify(() => mockAuth.currentUser).called(1);
    },
  );
});
```

### With simple fakes

For simple cases, a hand-written fake is often clearer than a mock:

```dart
class FakeAuthService implements AuthService {
  @override
  User get currentUser => User(name: 'Fake User');

  @override
  Future<void> login() async {}
}

test('module with fake auth', () async {
  await testModule(
    ProfileModule(),
    overrides: (binder) {
      binder.registerSingleton<AuthService>(FakeAuthService());
    },
    (module, binder) {
      final profile = binder.get<ProfileService>();
      expect(profile.userName, equals('Fake User'));
    },
  );
});
```

## Manual Controller Tests

For tests that need direct `ModuleController` access, always dispose manually:

```dart
test('manual controller lifecycle', () async {
  final controller = ModuleController(MyModule());

  await controller.initialize(<ModuleRegistryKey, ModuleController>{});
  expect(controller.currentStatus, equals(ModuleStatus.loaded));

  await controller.dispose();
  expect(controller.currentStatus, equals(ModuleStatus.disposed));
});
```

::: warning
`testModule()` automatically disposes the controller. Only create `ModuleController` directly when you need to test lifecycle states or interceptor behavior.
:::
