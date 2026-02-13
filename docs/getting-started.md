# 🚀 Getting Started

Add Modularity to a Flutter app, create a module, and access dependencies from the widget tree.

## Installation

```yaml
dependencies:
  modularity_core: ^0.2.0
  modularity_flutter: ^0.2.0
```

`modularity_contracts` is pulled in automatically.

::: tip Dart Workspace
In a monorepo, list packages under root `pubspec.yaml` with a `workspace:` key. Each member needs `resolution: workspace` in its own pubspec.
:::

## Create a Module

Extend `Module`. Register private dependencies in `binds()` and public ones in `exports()`:

```dart
import 'package:modularity_core/modularity_core.dart';

class AuthModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
    i.registerFactory<LoginUseCase>(
      () => LoginUseCase(i.get<AuthRepository>()),
    );
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<AuthService>(
      () => AuthService(i.get<AuthRepository>()),
    );
  }
}
```

- `binds()` -- private to this module.
- `exports()` -- visible to modules that import `AuthModule`.

### Registration Methods

| Method | Behaviour |
|--------|-----------|
| `registerLazySingleton<T>(() => ...)` | Created once on first `get<T>()` |
| `registerFactory<T>(() => ...)` | New instance every `get<T>()` |
| `registerSingleton<T>(instance)` | Eager -- same instance always |

## Wire the App

Two widgets connect modules to Flutter:

| Component | Role |
|-----------|------|
| `ModularityRoot` | Top-level `InheritedWidget`. Holds the global registry and `BinderFactory`. |
| `ModuleScope<T>` | Manages one module's lifecycle. |

::: tip Route Observer
The `routeBound` retention policy requires a `RouteObserver`. Create one externally and pass it to both `ModularityRoot(observer: ...)` and your router's `navigatorObservers`.
:::

::: warning Default Retention Policy
The default retention policy is `routeBound`, which means an observer **must** be passed to `ModularityRoot(observer: ...)` and added to `navigatorObservers`. If you don't need route-bound retention, explicitly set `retentionPolicy: ModuleRetentionPolicy.strict` on your `ModuleScope` to skip the observer requirement.
:::

```dart
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

final observer = RouteObserver<ModalRoute<dynamic>>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      observer: observer,
      defaultLoadingBuilder: (_) =>
          const Center(child: CircularProgressIndicator()),
      defaultErrorBuilder: (_, error, retry) => Center(
        child: TextButton(onPressed: retry, child: Text('Retry: $error')),
      ),
      child: MaterialApp(
        navigatorObservers: [observer],
        home: ModuleScope<AuthModule>(
          module: AuthModule(),
          child: const LoginPage(),
        ),
      ),
    );
  }
}
```

::: warning
`ModularityRoot` must be above any `ModuleScope` in the widget tree.
:::

## Access Dependencies

Use `ModuleProvider.of(context)` inside a `ModuleScope` subtree to get the `Binder`:

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = ModuleProvider.of(context).get<AuthService>();

    return ElevatedButton(
      onPressed: () => authService.login(),
      child: const Text('Sign In'),
    );
  }
}
```

### Lookup Methods

| Method | Returns | When not found |
|--------|---------|----------------|
| `get<T>()` | `T` | Throws `DependencyNotFoundException` |
| `tryGet<T>()` | `T?` | Returns `null` |
| `parent<T>()` | `T` | Throws (parent scope only) |
| `tryParent<T>()` | `T?` | Returns `null` (parent scope only) |

::: info Resolution Order
`get<T>()` searches scopes in this order:

1. **Local** -- private + public bindings of the current module
2. **Imports** -- public exports of imported modules
3. **Parent** -- nearest ancestor `ModuleScope`

If nothing matches, `DependencyNotFoundException` is thrown with a list of available types.
:::

### Get the Module Instance

```dart
final auth = ModuleProvider.moduleOf<AuthModule>(context);
```

## Module Lifecycle

`ModuleController` drives a deterministic lifecycle:

```mermaid
stateDiagram-v2
    [*] --> initial
    initial --> loading : initialize()
    loading --> loaded : success
    loading --> error : failure
    loaded --> disposed : dispose()
    error --> loading : retry
    error --> disposed : dispose()
    disposed --> [*]
```

::: details Full Lifecycle Hooks Reference

| Hook | Timing |
|------|--------|
| `binds(Binder i)` | Sync, after imports resolved |
| `exports(Binder i)` | Sync, right after `binds()` |
| `onInit()` | Async, after binds/exports |
| `onDispose()` | On controller disposal |

:::

### Loading and Error UI

```dart
ModuleScope<PaymentModule>(
  module: PaymentModule(),
  loadingBuilder: (_) => const Shimmer(),
  errorBuilder: (_, error, retry) => ErrorBanner(
    message: error.toString(),
    onRetry: retry,
  ),
  child: const PaymentForm(),
)
```

::: tip Best Practices
- Fallback order: per-scope builder -> `ModularityRoot` defaults -> built-in placeholder.
- The `retry` callback disposes the failed controller and re-runs the full initialization cycle.
- Keep modules focused -- one feature domain per module.
:::
