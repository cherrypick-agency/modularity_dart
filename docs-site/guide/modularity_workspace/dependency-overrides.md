# Dependency Overrides

This guide covers how to replace, extend, and intercept dependency registrations at every level of the Modularity framework.

## Simple Overrides

### On `ModuleController`

Pass an `overrides` callback when creating a `ModuleController`. The callback receives the module's `Binder` and runs after `binds()` but before `exports()`:

```dart
class ApiService {
  String get baseUrl => 'https://api.production.com';
}

class FakeApiService implements ApiService {
  @override
  String get baseUrl => 'https://fake.test';
}

class NetworkModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<ApiService>(() => ApiService());
  }

  @override
  void exports(Binder binder) {
    binder.registerLazySingleton<ApiService>(() => binder.get<ApiService>());
  }
}

// In test or setup code:
final controller = ModuleController(
  NetworkModule(),
  overrides: (binder) {
    binder.registerSingleton<ApiService>(FakeApiService());
  },
);

await controller.initialize(<ModuleRegistryKey, ModuleController>{});
// binder.get<ApiService>() now returns FakeApiService
```

### On `ModuleScope` (Flutter)

In the widget tree, pass `overrides` directly to `ModuleScope`:

```dart
ModuleScope(
  module: NetworkModule(),
  overrides: (binder) {
    binder.registerSingleton<ApiService>(FakeApiService());
  },
  child: const NetworkPage(),
)
```

This is the simplest way to swap dependencies in widget tests or for feature flags.

---

## `ModuleOverrideScope` Tree

For modules with imports, simple overrides only affect the root module. To override bindings inside imported modules, use `ModuleOverrideScope` -- a hierarchical tree that maps module types to their override callbacks.

### Structure

```dart
const overrideScope = ModuleOverrideScope(
  selfOverrides: ...,           // Override the root module
  children: {
    AuthModule: ModuleOverrideScope(
      selfOverrides: ...,       // Override AuthModule's bindings
    ),
    DataModule: ModuleOverrideScope(
      selfOverrides: ...,       // Override DataModule's bindings
      children: {
        CacheModule: ModuleOverrideScope(
          selfOverrides: ...,   // Override CacheModule inside DataModule
        ),
      },
    ),
  },
);
```

### `selfOverrides`

A `void Function(Binder)` callback applied to the module at this level of the tree. It replaces or adds registrations in the module's binder:

```dart
ModuleOverrideScope(
  selfOverrides: (binder) {
    binder.registerLazySingleton<AuthService>(() => MockAuthService());
  },
)
```

### `children`

A `Map<Type, ModuleOverrideScope>` keyed by the imported module's runtime type. When the `GraphResolver` initializes an imported module, it looks up the child scope by type and passes it down:

```dart
class AppModule extends Module {
  @override
  List<Module> get imports => [AuthModule(), DataModule()];

  @override
  void binds(Binder binder) {}
}

final overrideScope = ModuleOverrideScope(
  children: {
    AuthModule: ModuleOverrideScope(
      selfOverrides: (binder) {
        binder.registerLazySingleton<AuthService>(() => FakeAuthService());
      },
    ),
  },
);

// On ModuleController:
final controller = ModuleController(
  AppModule(),
  overrideScopeTree: overrideScope,
);

// On ModuleScope (Flutter):
ModuleScope(
  module: AppModule(),
  overrideScope: overrideScope,
  child: const AppPage(),
)
```

### `withAdditionalOverride()`

Creates a new scope that chains an additional override callback after the existing `selfOverrides`:

```dart
final base = ModuleOverrideScope(
  selfOverrides: (binder) {
    binder.registerSingleton<String>('base');
  },
);

final extended = base.withAdditionalOverride((binder) {
  binder.registerSingleton<int>(42);
});

// extended.selfOverrides applies 'base' first, then adds int(42)
```

### `merge()`

Combines two scopes into one. Self overrides are composed in order (receiver first, argument second). Children maps are merged recursively when keys overlap:

```dart
final scopeA = ModuleOverrideScope(
  selfOverrides: (binder) {
    binder.registerSingleton<String>('from-a');
  },
  children: {
    AuthModule: ModuleOverrideScope(
      selfOverrides: (binder) {
        binder.registerSingleton<int>(1);
      },
    ),
  },
);

final scopeB = ModuleOverrideScope(
  children: {
    AuthModule: ModuleOverrideScope(
      selfOverrides: (binder) {
        binder.registerSingleton<double>(2.0);
      },
    ),
    DataModule: ModuleOverrideScope(
      selfOverrides: (binder) {
        binder.registerSingleton<bool>(true);
      },
    ),
  },
);

final merged = scopeA.merge(scopeB);
// merged.selfOverrides -> String('from-a')
// merged.children[AuthModule] -> int(1) then double(2.0)
// merged.children[DataModule] -> bool(true)
```

---

## Override Timing

Understanding when overrides are applied is important for correct behavior.

### Lifecycle order

During `ModuleController.initialize()`, the lifecycle runs in this order:

1. **Resolve imports** -- imported modules are initialized recursively
2. **Add imports** -- import binders are added to the current binder
3. **Validate `expects`** -- expected types are checked in imports/parent
4. **`binds()`** -- module registers its private dependencies
5. **Apply overrides** -- `selfOverrides` callback runs on the binder
6. **`exports()`** -- module registers public dependencies
7. **Seal public scope** -- no more export registrations allowed
8. **`onInit()`** -- async initialization

```
imports resolved -> binds() -> overrides() -> exports() -> seal -> onInit()
```

Because overrides run between `binds()` and `exports()`, they can replace any private registration before it gets exported. Exported dependencies that call `binder.get<T>()` will pick up the overridden instance.

### Hot reload

During `hotReload()`, overrides are re-applied after `binds()` using the same scope:

```
binds() -> overrides() -> exports()
```

This means overrides persist across hot reloads without any additional setup.

---

## Interceptors

`ModuleInterceptor` provides lifecycle hooks for cross-cutting concerns like logging and analytics.

### Defining an interceptor

```dart
class TimingInterceptor implements ModuleInterceptor {
  final _timers = <Type, Stopwatch>{};

  @override
  void onInit(Module module) {
    _timers[module.runtimeType] = Stopwatch()..start();
  }

  @override
  void onLoaded(Module module) {
    final elapsed = _timers[module.runtimeType]?.elapsed;
    print('${module.runtimeType} loaded in $elapsed');
  }

  @override
  void onError(Module module, Object error) {
    print('${module.runtimeType} failed: $error');
  }

  @override
  void onDispose(Module module) {
    _timers.remove(module.runtimeType);
  }
}
```

### Lifecycle events

| Event | When |
|-------|------|
| `onInit(module)` | Before initialization starts (before imports are resolved) |
| `onLoaded(module)` | After `onInit()` completes successfully |
| `onError(module, error)` | When initialization throws |
| `onDispose(module)` | When the module is disposed |

### Per-controller interceptors

Pass interceptors to a specific `ModuleController`:

```dart
final controller = ModuleController(
  MyModule(),
  interceptors: [TimingInterceptor(), AnalyticsInterceptor()],
);
```

### Global interceptors via `Modularity.interceptors`

In Flutter apps, `ModuleScope` automatically passes `Modularity.interceptors` to every controller it creates:

```dart
void main() {
  Modularity.interceptors.addAll([
    TimingInterceptor(),
    ErrorReportingInterceptor(),
  ]);

  runApp(
    ModularityRoot(
      child: MyApp(),
    ),
  );
}
```

All `ModuleScope` widgets in the tree will receive these interceptors.

---

## Lifecycle Logging

Modularity provides a built-in logging system for module retention events (creation, reuse, disposal, cache operations).

### Quick setup

Enable default console logging with one call:

```dart
void main() {
  Modularity.enableDebugLogging();
  runApp(ModularityRoot(child: MyApp()));
}
```

This prints events like:

```
[Modularity] CREATED ProfileModule key=ProfileModule-/profile
[Modularity] REGISTERED ProfileModule key=ProfileModule-/profile
[Modularity] REUSED ProfileModule key=ProfileModule-/profile
[Modularity] ROUTETERMINATED ProfileModule key=ProfileModule-/profile
[Modularity] EVICTED ProfileModule key=ProfileModule-/profile
```

### `ModuleLifecycleEvent`

| Event | Description |
|-------|-------------|
| `created` | Controller created for the first time |
| `reused` | Existing controller reused from cache |
| `registered` | Controller registered in retention cache |
| `disposed` | Controller disposed |
| `evicted` | Controller evicted from retention cache |
| `released` | Controller released (ref count decremented) |
| `routeTerminated` | Route termination triggered controller cleanup |

### Custom logger

Set `Modularity.lifecycleLogger` to a custom callback:

```dart
Modularity.lifecycleLogger = (event, moduleType, {retentionKey, details}) {
  myLogger.info(
    'Module event',
    extra: {
      'event': event.name,
      'module': moduleType.toString(),
      'key': retentionKey?.toString(),
      ...?details,
    },
  );
};
```

### Disable logging

```dart
Modularity.disableLogging();
```

### Logging in tests

Use the lifecycle logger to verify module lifecycle in widget tests:

```dart
testWidgets('lifecycle events fire correctly', (tester) async {
  final log = <String>[];

  Modularity.lifecycleLogger = (event, type, {retentionKey, details}) {
    log.add('${event.name}:$type');
  };

  await tester.pumpWidget(
    ModularityRoot(
      child: MaterialApp(
        home: ModuleScope(
          module: MyModule(),
          retentionPolicy: ModuleRetentionPolicy.keepAlive,
          retentionKey: 'test-key',
          child: const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(log, containsAll([contains('created'), contains('registered')]));

  Modularity.disableLogging();
});
```

---

## Use Cases

### Feature flags

Swap service implementations based on feature flags:

```dart
ModuleScope(
  module: PaymentModule(),
  overrides: (binder) {
    if (FeatureFlags.newCheckout) {
      binder.registerLazySingleton<CheckoutFlow>(() => NewCheckoutFlow());
    }
  },
  child: const CheckoutPage(),
)
```

### A/B testing

Use `overrideScope` to inject different variants for imported modules:

```dart
final overrideScope = ModuleOverrideScope(
  children: {
    UIModule: ModuleOverrideScope(
      selfOverrides: (binder) {
        binder.registerSingleton<ThemeConfig>(
          isVariantB ? ThemeConfig.modern() : ThemeConfig.classic(),
        );
      },
    ),
  },
);

ModuleScope(
  module: AppModule(),
  overrideScope: overrideScope,
  child: const AppShell(),
)
```

### Environment-specific DI

Override production services for development or staging:

```dart
ModuleController(
  AppModule(),
  overrides: (binder) {
    if (kDebugMode) {
      binder.registerSingleton<AnalyticsService>(NoOpAnalytics());
      binder.registerSingleton<CrashReporter>(ConsoleCrashReporter());
    }
  },
);
```

### Debug tools

Combine interceptors and logging for a complete debug experience:

```dart
void configureDebugTools() {
  // 1. Global interceptors for timing and error tracking
  Modularity.interceptors.add(TimingInterceptor());

  // 2. Lifecycle logging for retention debugging
  Modularity.enableDebugLogging();

  // 3. Override slow services with fast fakes
  // (via overrideScope on specific ModuleScopes)
}
```

### Test isolation with scoped overrides

Each test can use a different override scope without affecting other tests:

```dart
group('PaymentModule', () {
  test('with Stripe gateway', () async {
    await testModule(
      PaymentModule(),
      overrides: (binder) {
        binder.registerSingleton<PaymentGateway>(StripeGateway());
      },
      (module, binder) {
        expect(binder.get<PaymentGateway>(), isA<StripeGateway>());
      },
    );
  });

  test('with PayPal gateway', () async {
    await testModule(
      PaymentModule(),
      overrides: (binder) {
        binder.registerSingleton<PaymentGateway>(PayPalGateway());
      },
      (module, binder) {
        expect(binder.get<PaymentGateway>(), isA<PayPalGateway>());
      },
    );
  });
});
```
