# Testing Modules

This guide covers testing strategies for Modularity modules, from isolated unit tests to full widget integration tests.

## Unit Testing with `testModule()`

The `modularity_test` package provides `testModule()` -- a helper that runs the full module lifecycle (resolve imports, binds, exports, onInit) and hands you a `TestBinder` that records every registration and resolution.

### Setup

Add the dependency to your `dev_dependencies`:

```yaml
dev_dependencies:
  modularity_test:
    path: ../packages/modularity_test  # or published version
  test: ^1.25.0
```

### Basic test

```dart
import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_test/modularity_test.dart';
import 'package:test/test.dart';

class ApiClient {}

class AuthRepository {
  AuthRepository(this.client);
  final ApiClient client;
}

class AuthModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<ApiClient>(() => ApiClient());
    binder.registerFactory<AuthRepository>(
      () => AuthRepository(binder.get<ApiClient>()),
    );
  }
}

void main() {
  test('AuthModule registers expected dependencies', () async {
    await testModule(AuthModule(), (module, binder) {
      // Verify registration types
      expect(binder.hasSingleton<ApiClient>(), isTrue);
      expect(binder.hasFactory<AuthRepository>(), isTrue);

      // Verify resolution
      final repo = binder.get<AuthRepository>();
      expect(repo, isA<AuthRepository>());
      expect(binder.wasResolved<AuthRepository>(), isTrue);
    });
  });
}
```

### TestBinder assertions

`TestBinder` wraps the real `SimpleBinder` and records all interactions:

| Method | Description |
|--------|-------------|
| `hasSingleton<T>()` | Was `T` registered via `registerLazySingleton`? |
| `hasFactory<T>()` | Was `T` registered via `registerFactory`? |
| `hasInstance<T>()` | Was `T` registered via `registerSingleton` (eager)? |
| `wasResolved<T>()` | Was `T` retrieved via `get` or `tryGet`? |
| `registeredSingletons` | All types registered as singletons |
| `registeredFactories` | All types registered as factories |
| `registeredInstances` | All types registered as eager instances |
| `resolvedTypes` | All types that were resolved |

---

## Overriding Dependencies

Pass an `overrides` callback to `testModule()` to replace real implementations with fakes or mocks:

```dart
class HttpClient {
  String fetch(String url) => throw UnimplementedError();
}

class FakeHttpClient implements HttpClient {
  @override
  String fetch(String url) => '{"ok": true}';
}

class NetworkModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<HttpClient>(() => HttpClient());
  }
}

test('override HttpClient with fake', () async {
  await testModule(
    NetworkModule(),
    overrides: (binder) {
      binder.registerSingleton<HttpClient>(FakeHttpClient());
    },
    (module, binder) {
      final client = binder.get<HttpClient>();
      expect(client, isA<FakeHttpClient>());
      expect(client.fetch('/api'), equals('{"ok": true}'));
    },
  );
});
```

Overrides are applied **after** `binds()` but **before** `exports()`, so they replace the module's own registrations before anything is exported to dependents.

---

## Hierarchical Overrides with `ModuleOverrideScope`

When a module imports other modules, you can target overrides at specific imported modules using `ModuleOverrideScope`:

```dart
class DatabaseService {
  String get name => 'real';
}

class FakeDatabaseService implements DatabaseService {
  @override
  String get name => 'fake';
}

class DataModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<DatabaseService>(() => DatabaseService());
  }

  @override
  void exports(Binder binder) {
    binder.registerLazySingleton<DatabaseService>(
      () => binder.get<DatabaseService>(),
    );
  }
}

class AppModule extends Module {
  @override
  List<Module> get imports => [DataModule()];

  @override
  void binds(Binder binder) {
    // Uses DatabaseService from DataModule
  }
}
```

Override `DataModule`'s bindings from the parent:

```dart
test('override imported DataModule bindings', () async {
  final overrideScope = ModuleOverrideScope(
    children: {
      DataModule: ModuleOverrideScope(
        selfOverrides: (binder) {
          binder.registerLazySingleton<DatabaseService>(
            () => FakeDatabaseService(),
          );
        },
      ),
    },
  );

  await testModule(
    AppModule(),
    overrideScope: overrideScope,
    (module, binder) {
      final db = binder.get<DatabaseService>();
      expect(db.name, equals('fake'));
    },
  );
});
```

### Combining self and child overrides

You can override both the root module and its children in a single scope:

```dart
final overrideScope = ModuleOverrideScope(
  selfOverrides: (binder) {
    // Override something in AppModule itself
    binder.registerSingleton<String>('test-env');
  },
  children: {
    DataModule: ModuleOverrideScope(
      selfOverrides: (binder) {
        binder.registerLazySingleton<DatabaseService>(
          () => FakeDatabaseService(),
        );
      },
    ),
  },
);
```

### Merging override scopes

Use `merge()` to combine two scopes. Overlapping children are merged recursively:

```dart
final base = ModuleOverrideScope(
  children: {
    DataModule: ModuleOverrideScope(
      selfOverrides: (binder) {
        binder.registerSingleton<String>('base-config');
      },
    ),
  },
);

final extra = ModuleOverrideScope(
  children: {
    DataModule: ModuleOverrideScope(
      selfOverrides: (binder) {
        binder.registerSingleton<int>(42);
      },
    ),
  },
);

final merged = base.merge(extra);
// DataModule now gets both String('base-config') and int(42)
```

---

## Widget Testing with `ModuleScope`

For Flutter widget tests, wrap your widget under test in `ModularityRoot` + `ModuleScope`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

class UserService {
  String get name => 'Real User';
}

class FakeUserService implements UserService {
  @override
  String get name => 'Test User';
}

class ProfileModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<UserService>(() => UserService());
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final binder = ModuleProvider.of(context);
    final user = binder.get<UserService>();
    return Text(user.name);
  }
}

void main() {
  testWidgets('ProfilePage shows user name', (tester) async {
    await tester.pumpWidget(
      ModularityRoot(
        child: MaterialApp(
          home: ModuleScope(
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
}
```

### Nested scopes in widget tests

Test parent-child scope chaining by nesting `ModuleScope` widgets:

```dart
testWidgets('child module reads from parent scope', (tester) async {
  await tester.pumpWidget(
    ModularityRoot(
      child: MaterialApp(
        home: ModuleScope(
          module: ParentModule(),
          child: ModuleScope(
            module: ChildModule(),
            child: Builder(
              builder: (context) {
                final binder = ModuleProvider.of(context);
                final data = binder.get<SharedData>();
                return Text(data.value);
              },
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('from-parent'), findsOneWidget);
});
```

### Override scopes in widget tests

Pass `overrideScope` to `ModuleScope` to override imported module bindings in the widget tree:

```dart
testWidgets('override imported module in widget tree', (tester) async {
  final overrideScope = ModuleOverrideScope(
    children: {
      AuthModule: ModuleOverrideScope(
        selfOverrides: (binder) {
          binder.registerLazySingleton<AuthService>(
            () => FakeAuthService(),
          );
        },
      ),
    },
  );

  await tester.pumpWidget(
    ModularityRoot(
      child: MaterialApp(
        home: ModuleScope(
          module: AppModule(),
          overrideScope: overrideScope,
          child: const AppPage(),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('Logged in as: test-user'), findsOneWidget);
});
```

---

## Testing Tips

### Verify registration expectations

Check that a module registers exactly the types you expect:

```dart
test('module registers all expected types', () async {
  await testModule(PaymentModule(), (module, binder) {
    expect(binder.registeredSingletons, containsAll([PaymentGateway, OrderRepository]));
    expect(binder.registeredFactories, contains(PaymentProcessor));
    expect(binder.registeredSingletons, isNot(contains(InternalHelper)));
  });
});
```

### Testing async `onInit`

`testModule()` awaits the full lifecycle including `onInit()`. If `onInit` performs async setup, it completes before the body runs:

```dart
class CacheModule extends Module {
  bool initialized = false;

  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<String>(() => 'cache');
  }

  @override
  Future<void> onInit() async {
    await Future.delayed(Duration(milliseconds: 10));
    initialized = true;
  }
}

test('onInit completes before test body', () async {
  await testModule(CacheModule(), (module, binder) {
    expect(module.initialized, isTrue);
  });
});
```

### Testing error recovery in widgets

Use `ModuleScope`'s built-in error/retry UI to verify recovery logic:

```dart
class FlakyModule extends Module {
  static int attempts = 0;

  @override
  void binds(Binder binder) {}

  @override
  Future<void> onInit() async {
    attempts++;
    if (attempts == 1) throw Exception('Init Failed');
  }
}

testWidgets('retry recovers from initialization failure', (tester) async {
  FlakyModule.attempts = 0;

  await tester.pumpWidget(
    ModularityRoot(
      child: MaterialApp(
        home: ModuleScope(
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
  expect(FlakyModule.attempts, 2);
});
```

### Testing circular dependency detection

Circular imports are caught at initialization time with a `CircularDependencyException`:

```dart
class ModuleA extends Module {
  @override
  List<Module> get imports => [ModuleB()];

  @override
  void binds(Binder binder) {}
}

class ModuleB extends Module {
  @override
  List<Module> get imports => [ModuleA()];

  @override
  void binds(Binder binder) {}
}

test('circular imports throw CircularDependencyException', () async {
  final controller = ModuleController(ModuleA());

  await expectLater(
    () => controller.initialize(<ModuleRegistryKey, ModuleController>{}),
    throwsA(isA<CircularDependencyException>()),
  );
});
```

### Testing `expects` validation

Verify that missing expected dependencies produce clear errors:

```dart
class StrictModule extends Module {
  @override
  List<Type> get expects => [AuthService];

  @override
  void binds(Binder binder) {}
}

test('missing expects throw ModuleConfigurationException', () async {
  final controller = ModuleController(StrictModule());

  await expectLater(
    () => controller.initialize(<ModuleRegistryKey, ModuleController>{}),
    throwsA(isA<ModuleConfigurationException>()),
  );
});
```

### Disposing in tests

`testModule()` automatically disposes the controller after the body runs. For manual `ModuleController` tests, always dispose:

```dart
test('manual controller lifecycle', () async {
  final controller = ModuleController(MyModule());
  final registry = <ModuleRegistryKey, ModuleController>{};

  await controller.initialize(registry);

  // ... assertions ...

  await controller.dispose();
  expect(controller.currentStatus, equals(ModuleStatus.disposed));
});
```
