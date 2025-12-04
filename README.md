# Modularity Framework

![coverage](https://img.shields.io/badge/coverage-61.4%25-yellow)

<img alt="image" src="https://github.com/user-attachments/assets/40749462-0892-4996-8c94-093c433d7b43" />

A modular architecture framework for Flutter applications based on Clean Architecture & SOLID principles. Designed for enterprise-scale apps requiring strict isolation, testability, and a predictable lifecycle.

Repository: [github.com/cherrypick-agency/modularity_dart](https://github.com/cherrypick-agency/modularity_dart)

---

## 📑 Table of Contents

- [📦 Packages](#-packages)
- [🚀 Key Features](#-key-features)
- [⚖️ Comparison](#️-comparison)
- [🛠 Getting Started](#-getting-started)
  - [1. Define a Module](#1-define-a-module)
  - [2. Initialize Root](#2-initialize-root)
  - [3. Use in UI](#3-use-in-ui)
- [🧩 Advanced Features](#-advanced-features)
  - [Lifecycle Hooks (onInit / onDispose)](#lifecycle-hooks-oninit--ondispose)
  - [Configurable Modules](#configurable-modules)
  - [Expected Dependencies (expects)](#expected-dependencies-expects)
  - [Module Interceptors](#module-interceptors)
  - [Scoped Overrides (ModuleOverrideScope)](#scoped-overrides-moduleoverridescope)
  - [Submodules (Static Analysis)](#submodules-static-analysis)
  - [Hot Reload Support](#hot-reload-support)
  - [Custom Retention Identity](#custom-retention-identity)
  - [ModularityRoot Configuration](#modularityroot-configuration)
- [🔌 Router Integration](#-router-integration)
  - [GoRouter](#gorouter)
  - [AutoRoute](#autoroute)
- [📊 CLI Visualization](#-cli-visualization)
- [🔧 DI Container Adapters](#-di-container-adapters)
  - [GetIt Integration](#getit-integration)
  - [Injectable Integration](#injectable-integration)
- [🧪 Testing](#-testing)
- [🔍 Diagnostics](#-diagnostics)
  - [Binder Graph](#binder-graph)
  - [Lifecycle Logging](#lifecycle-logging)
- [📖 Binder API Reference](#-binder-api-reference)
- [⚠️ Retention Key vs Override Scope](#️-retention-key-vs-override-scope)

---

## 📦 Packages

| Package | Version | Pub Points | Description |
| ------- | ------- | ---------- | ----------- |
| [modularity_contracts](https://pub.dev/packages/modularity_contracts) | [![pub](https://img.shields.io/pub/v/modularity_contracts.svg)](https://pub.dev/packages/modularity_contracts) | [![pub points](https://img.shields.io/pub/points/modularity_contracts)](https://pub.dev/packages/modularity_contracts/score) | Zero-dependency interfaces |
| [modularity_core](https://pub.dev/packages/modularity_core) | [![pub](https://img.shields.io/pub/v/modularity_core.svg)](https://pub.dev/packages/modularity_core) | [![pub points](https://img.shields.io/pub/points/modularity_core)](https://pub.dev/packages/modularity_core/score) | DI container and state machine logic |
| [modularity_flutter](https://pub.dev/packages/modularity_flutter) | [![pub](https://img.shields.io/pub/v/modularity_flutter.svg)](https://pub.dev/packages/modularity_flutter) | [![pub points](https://img.shields.io/pub/points/modularity_flutter)](https://pub.dev/packages/modularity_flutter/score) | Flutter widgets and RouteObserver integration |
| [modularity_test](https://pub.dev/packages/modularity_test) | [![pub](https://img.shields.io/pub/v/modularity_test.svg)](https://pub.dev/packages/modularity_test) | [![pub points](https://img.shields.io/pub/points/modularity_test)](https://pub.dev/packages/modularity_test/score) | Unit testing utilities (testModule) |
| [modularity_cli](https://pub.dev/packages/modularity_cli) | [![pub](https://img.shields.io/pub/v/modularity_cli.svg)](https://pub.dev/packages/modularity_cli) | [![pub points](https://img.shields.io/pub/points/modularity_cli)](https://pub.dev/packages/modularity_cli/score) | Graph visualization tools |
| [modularity_get_it](https://pub.dev/packages/modularity_get_it) | [![pub](https://img.shields.io/pub/v/modularity_get_it.svg)](https://pub.dev/packages/modularity_get_it) | [![pub points](https://img.shields.io/pub/points/modularity_get_it)](https://pub.dev/packages/modularity_get_it/score) | GetIt adapter for Modularity |
| [modularity_injectable](https://pub.dev/packages/modularity_injectable) | [![pub](https://img.shields.io/pub/v/modularity_injectable.svg)](https://pub.dev/packages/modularity_injectable) | [![pub points](https://img.shields.io/pub/points/modularity_injectable)](https://pub.dev/packages/modularity_injectable/score) | Optional injectable + GetIt integration |

## 🚀 Key Features

- **Strict Dependency Injection**: Dependencies are explicitly `imported` and `exported`. No hidden global access.
- **Deterministic Lifecycle**: Modules pass through a formal state machine (`initial` → `loading` → `loaded` → `disposed`). `onInit` runs only after all imports are ready.
- **Retention Policies**: Formal `ModuleRetentionPolicy` enum (`routeBound`, `keepAlive`, `strict`) with pluggable strategies and cache-backed retainer.
- **Framework Agnostic**: Works with GoRouter, AutoRoute, or Navigator 1.0.
- **Observability**: Built-in interceptors and Graphviz visualization support.

## ⚖️ Comparison

How **Modularity** compares to other popular approaches in the Flutter ecosystem:

| Feature | Modularity (This Framework) | Flutter Modular | Provider / Riverpod / BLoC |
| :--- | :--- | :--- | :--- |
| **Module Definition** | **Pure Dart class + State Machine**. Encapsulated logic decoupled from UI. | **Class with routes & binds**. Strongly coupled to the router and UI navigation. | **Folder structure / Providers list**. No formal module concept; usually just a list of global or scoped providers. |
| **Initialization** | **Automatic (DAG)**. `onInit` is guaranteed to run after all imports are resolved and initialized. Solves "Initialization Hell". | **Lazy or Navigation-based**. initialization happens when the route is accessed or the bind is called. | **Lazy or Widget-mount**. Initialization happens when the widget tree is built or the provider is first read. |
| **Dependency Management** | **Explicit**. Uses `imports`, `exports`, and `binds`. Modules cannot access what they don't strictly import. | **Module Tree / Global**. Hierarchical scoping, but often allows accessing parent scopes implicitly. | **Global / Scoped**. `ProviderScope` or `MultiBlocProvider` in the widget tree. Dependencies often implicit via `context.read`. |
| **Lifecycle** | **Formal State Machine**. Strict states (`initial`, `loading`, `loaded`, `disposed`) managed by the core engine. | **Bound to Router**. Lifecycle is tied to Modular's internal router and navigation stack. | **Bound to Widget Tree**. Lifecycle is tied to the `BuildContext` (StatefulWidget) or Provider's auto-dispose logic. |
| **Routing Coupling** | **Loose**. Works with any router (GoRouter, AutoRoute, etc.). Routing is an implementation detail. | **Strong**. The router is a core part of the framework. Hard to use with other routing solutions. | **Indirect**. No direct coupling, but state management often gets entangled with navigation arguments. |
| **Testing** | **Unit-first**. `testModule` isolates logic completely. You can test the entire wiring without Flutter. | **Integration mainly**. Focuses on testing the module with the router mocked or real. | **Widget tests required**. Often requires `pumpWidget` to test the DI integration properly. |

## 🛠 Getting Started

### 1. Define a Module

```dart
import 'package:modularity_contracts/modularity_contracts.dart';

class AppModule extends Module {
  @override
  List<Module> get imports => [ /* SharedModule() */ ];

  @override
  void binds(Binder binder) {
    // Private: Implementation details
    binder.singleton<AuthRepository>(() => AuthRepositoryImpl());
  }

  @override
  void exports(Binder binder) {
    // Public: Exposed API
    binder.singleton<AuthService>(() => AuthService(binder.get()));
  }
}
```

> **Prefer code generation?** If you'd rather use `injectable` for auto-wiring, see [modularity_injectable](packages/modularity_injectable/README.md). It's entirely optional — manual registration works great for most projects.

### 2. Initialize Root

```dart
void main() {
  runApp(ModularityRoot(
    child: MaterialApp(
      navigatorObservers: [Modularity.observer], // Required for routeBound policy
      home: ModuleScope(
        module: AppModule(),
        child: HomePage(),
      ),
    ),
  ));
}
```

> **Important**: Add `Modularity.observer` to `navigatorObservers` to enable automatic module disposal when routes pop.

> Need to keep modules alive across tab switches or background navigation layers? Set the retention policy explicitly:
>
> ```dart
> ModuleScope(
>   module: ProfileModule(),
>   retentionPolicy: ModuleRetentionPolicy.keepAlive,
>   child: ProfilePage(),
> );
> ```

### 3. Use in UI

```dart
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Type-safe dependency resolution
    final authService = ModuleProvider.of(context).get<AuthService>();
    
    return Text('Logged in: ${authService.isLoggedIn}');
  }
}
```

## 🧩 Advanced Features

### Lifecycle Hooks (onInit / onDispose)

Use `onInit` for async initialization after all imports are ready:

```dart
class AuthModule extends Module {
  @override
  List<Module> get imports => [ConfigModule()];
  
  @override
  void binds(Binder binder) {
    binder.lazySingleton<AuthService>(() => AuthServiceImpl(
      binder.get<Config>(), // From ConfigModule
    ));
  }
  
  @override
  Future<void> onInit() async {
    // Called AFTER binds() and all imports are loaded
    // Access dependencies via controller if needed
  }
  
  @override
  void onDispose() {
    // Cleanup resources when module is disposed
  }
}
```

### Configurable Modules

When a module needs runtime parameters (e.g., entity ID from route arguments), implement `Configurable<T>`:

```dart
class ProductDetailsModule extends Module implements Configurable<String> {
  late String productId;

  @override
  void configure(String id) {
    productId = id;
  }

  @override
  void binds(Binder binder) {
    binder.singleton<ProductRepository>(() => ProductRepositoryImpl());
    binder.singleton<ProductBloc>(() => ProductBloc(binder.get(), productId));
  }
}
```

Pass arguments via `ModuleScope`:

```dart
ModuleScope(
  module: ProductDetailsModule(),
  args: productId, // Passed to configure() before binds()
  child: ProductDetailsPage(),
)
```

### Expected Dependencies (expects)

Declare required dependencies from parent scope for fail-fast initialization:

```dart
class ProfileModule extends Module {
  @override
  List<Module> get imports => [/* ... */];
  
  @override
  List<Type> get expects => [UserService, AnalyticsService];
  
  @override
  void binds(Binder binder) {
    // Safe to use — framework validates presence before binds()
    binder.singleton<ProfileBloc>(
      () => ProfileBloc(binder.get<UserService>()),
    );
  }
}
```

If any `expects` type is missing, initialization throws with a descriptive error.

### Module Interceptors

Intercept lifecycle events for logging, analytics, or debugging:

```dart
class AnalyticsInterceptor implements ModuleInterceptor {
  @override
  void onInit(Module module) {
    analytics.track('module_init', {'type': module.runtimeType.toString()});
  }

  @override
  void onLoaded(Module module) {
    analytics.track('module_loaded', {'type': module.runtimeType.toString()});
  }

  @override
  void onError(Module module, Object error) {
    crashlytics.recordError(error, reason: 'Module ${module.runtimeType} failed');
  }

  @override
  void onDispose(Module module) {
    analytics.track('module_disposed', {'type': module.runtimeType.toString()});
  }
}

// Register globally
void main() {
  Modularity.interceptors.add(AnalyticsInterceptor());
  runApp(MyApp());
}
```

### Scoped Overrides (ModuleOverrideScope)

Override dependencies in imported modules without modifying them — perfect for testing and feature flags:

```dart
// Override AuthModule's internal dependency when used by DashboardModule
final overrides = ModuleOverrideScope(children: {
  AuthModule: ModuleOverrideScope(
    selfOverrides: (binder) {
      binder.lazySingleton<AuthApi>(() => MockAuthApi());
    },
  ),
});

ModuleScope(
  module: DashboardModule(),
  overrideScope: overrides,
  child: DashboardPage(),
)
```

In tests:

```dart
await testModule(
  DashboardModule(),
  (module, binder) {
    // AuthApi is now MockAuthApi
    expect(binder.get<AuthService>().api, isA<MockAuthApi>());
  },
  overrideScope: overrides,
);
```

### Submodules (Static Analysis)

Declare structural relationships for visualization tools (no runtime effect):

```dart
class AppModule extends Module {
  @override
  List<Module> get imports => [CoreModule()];
  
  @override
  List<Module> get submodules => [
    AuthFeatureModule(),
    ProfileFeatureModule(),
    SettingsFeatureModule(),
  ];
}
```

Submodules appear in the dependency graph generated by `modularity_cli`.

### Hot Reload Support

Modules support Flutter's hot reload out of the box. Override `hotReload` for custom refresh logic:

```dart
class DashboardModule extends Module {
  @override
  void binds(Binder binder) {
    binder.lazySingleton<DashboardBloc>(() => DashboardBloc());
    binder.factory<ChartRenderer>(() => ChartRenderer()); // Always fresh
  }
  
  @override
  void hotReload(Binder binder) {
    // Called on hot reload — refresh factories without losing singleton state
    binder.factory<ChartRenderer>(() => ChartRenderer());
  }
}
```

During hot reload:
1. Singletons are preserved (same instance)
2. Factories are re-registered with new code
3. `ModuleOverrideScope` is re-applied automatically

### Custom Retention Identity

For advanced caching scenarios, implement `RetentionIdentityProvider`:

```dart
class UserProfileModule extends Module with RetentionIdentityProvider {
  final String userId;
  UserProfileModule(this.userId);
  
  @override
  Object? buildRetentionIdentity(ModuleRetentionContext context) {
    // Cache by userId, not just module type
    return 'user-profile-$userId';
  }
}
```

### ModularityRoot Configuration

Customize framework behavior at the root level:

```dart
ModularityRoot(
  // Custom Binder factory (e.g., GetItBinderFactory for GetIt integration)
  binderFactory: SimpleBinderFactory(),
  
  // Default Loading UI for all ModuleScopes
  defaultLoadingBuilder: (context) => const Center(
    child: CircularProgressIndicator(),
  ),
  
  // Default Error UI for all ModuleScopes
  defaultErrorBuilder: (context, error, retry) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Error: $error'),
        ElevatedButton(onPressed: retry, child: Text('Retry')),
      ],
    ),
  ),
  
  child: MaterialApp(...),
)
```

Override per-module with `ModuleScope`:

```dart
ModuleScope(
  module: ProfileModule(),
  loadingBuilder: (context) => ProfileShimmer(),
  errorBuilder: (context, error, retry) => ProfileErrorView(error, retry),
  child: ProfilePage(),
)
```

## 🔌 Router Integration

### GoRouter

```dart
final router = GoRouter(
  observers: [Modularity.observer], // Required!
  routes: [
    GoRoute(
      path: '/product/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ModuleScope(
          module: ProductModule(),
          args: id, // Configurable<String>
          child: ProductPage(),
        );
      },
    ),
  ],
);

// main.dart
runApp(ModularityRoot(
  child: MaterialApp.router(routerConfig: router),
));
```

### AutoRoute

```dart
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(path: '/product/:id', page: ProductRoute.page),
  ];
}

// main.dart
final appRouter = AppRouter();
runApp(ModularityRoot(
  child: MaterialApp.router(
    routerConfig: appRouter.config(
      navigatorObservers: () => [Modularity.observer],
    ),
  ),
));
```

## 📊 CLI Visualization

Generate dependency graphs with `modularity_cli`:

```dart
// tool/visualize.dart
import 'package:modularity_cli/modularity_cli.dart';

void main() async {
  await GraphVisualizer.visualize(
    AppModule(),
    renderer: GraphRenderer.g6, // Interactive AntV G6
  );
}
```

Run with `dart run tool/visualize.dart` — opens an interactive diagram showing:
- Module hierarchy and imports
- Public exports vs private bindings
- Dependency types (singleton, factory, instance)

| Renderer | Description |
|----------|-------------|
| `graphviz` | Static DOT diagram via quickchart.io |
| `g6` | Interactive drag-and-zoom with tooltips |

## 🔧 DI Container Adapters

### GetIt Integration

Use your existing GetIt setup with Modularity:

```dart
import 'package:modularity_get_it/modularity_get_it.dart';

void main() {
  runApp(ModularityRoot(
    binderFactory: GetItBinderFactory(), // Uses global GetIt.instance
    child: MaterialApp(...),
  ));
}
```

For isolated instances:

```dart
GetItBinderFactory(useGlobalInstance: false)
```

### Injectable Integration

For code generation with `injectable`:

```dart
// See modularity_injectable package
@InjectableInit()
void configureDependencies() => getIt.init();

void main() {
  configureDependencies();
  runApp(ModularityRoot(
    binderFactory: GetItBinderFactory(),
    child: MaterialApp(...),
  ));
}
```

## 🧪 Testing

Use `modularity_test` to verify your module's wiring and logic in isolation.

```dart
import 'package:modularity_test/modularity_test.dart';

void main() {
  test('AppModule registers AuthService', () async {
    await testModule(AppModule(), (module, binder) {
      expect(binder.get<AuthService>(), isNotNull);
      expect(binder.get<AuthService>().isLoggedIn, isFalse);
    });
  });
}
```

## 🔍 Diagnostics

### Binder Graph

Need to inspect which dependencies a real module contributes? After the controllers finish initialization you can dump the binder to see both private and exported tokens (plus imported scopes):

```dart
final registry = <ModuleRegistryKey, ModuleController>{};

final authController = ModuleController(AuthModule());
await authController.initialize(registry);

final dashboardController = ModuleController(DashboardModule());
await dashboardController.initialize(registry);

debugPrint(
  (dashboardController.binder as SimpleBinder).debugGraph(includeImports: true),
);
```

This prints something like:

```
SimpleBinder(4c1f)
  Private:
    - DashboardController
    - DashboardViewModel
  Public:
    - DashboardService
  Imports:
    SimpleBinder(13ab)
      Private:
        - AuthRepositoryImpl
      Public:
        - AuthService
```

Handy when you need to confirm that `AuthService` is exported while `AuthRepositoryImpl` stays private.

### Lifecycle Logging

Enable debug logging to trace module creation, caching, and disposal events:

```dart
void main() {
  // Enable default console logging (debug builds only recommended)
  Modularity.enableDebugLogging();

  runApp(MyApp());
}
```

Output example:

```
[Modularity] CREATED ConfigModule key=config-module {policy: keepAlive, hasOverrideScope: false}
[Modularity] REGISTERED ConfigModule key=config-module {policy: keepAlive, refCount: 1, hasRoute: true}
[Modularity] REUSED ConfigModule key=config-module {refCount: 2}
[Modularity] ROUTETERMINATED ConfigModule {routeType: MaterialPageRoute<dynamic>}
[Modularity] EVICTED ConfigModule key=config-module {disposeController: true}
[Modularity] DISPOSED ConfigModule key=config-module {reason: evicted}
```

For custom integrations (analytics, crash reporting), use a custom logger:

```dart
Modularity.lifecycleLogger = (event, type, {retentionKey, details}) {
  analytics.track('module_${event.name}', {
    'type': type.toString(),
    'key': retentionKey?.toString(),
    ...?details?.map((k, v) => MapEntry(k, v.toString())),
  });
};
```

Available events: `created`, `reused`, `registered`, `disposed`, `evicted`, `released`, `routeTerminated`.

## 📖 Binder API Reference

| Method | Description |
|--------|-------------|
| `factory<T>()` / `registerFactory<T>()` | New instance on each `get<T>()` call |
| `singleton<T>()` / `registerSingleton<T>()` | Instance created immediately |
| `lazySingleton<T>()` / `registerLazySingleton<T>()` | Instance created on first access |
| `get<T>()` | Retrieve dependency (throws if not found) |
| `tryGet<T>()` | Retrieve dependency (returns null if not found) |
| `contains<T>()` | Check if type is registered |
| `parent<T>()` | Get from parent scope only |

## ⚠️ Retention Key vs Override Scope

When using `keepAlive` retention policy, understand the distinction:

- **`retentionKey`** determines cache identity. Two `ModuleScope` widgets with the same key share the cached controller.
- **`overrideScope`** affects DI bindings but does NOT affect cache identity.

**Implication:** If you have two scopes with the same `retentionKey` but different `overrideScope`, they share a controller — first scope's overrides win.

```dart
// ❌ Problem: Both use same retentionKey, second overrides are ignored
ModuleScope(module: ConfigModule(), retentionKey: 'config', overrideScope: scopeA, ...)
ModuleScope(module: ConfigModule(), retentionKey: 'config', overrideScope: scopeB, ...) // shares controller with scopeA!

// ✅ Solution: Include scope identity in the key
ModuleScope(
  module: ConfigModule(),
  retentionKey: 'config-${identityHashCode(scopeA)}',
  overrideScope: scopeA,
  ...
)
```
