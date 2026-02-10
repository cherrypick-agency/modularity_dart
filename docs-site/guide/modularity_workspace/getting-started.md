# Getting Started

This guide walks you through adding Modularity to a Flutter app, creating your first module, and accessing dependencies from the widget tree.

## Installation

Add the core and Flutter packages to your `pubspec.yaml`:

```yaml
dependencies:
  modularity_core: ^0.2.0
  modularity_flutter: ^0.2.0
```

Both packages pull in `modularity_contracts` automatically.

### Workspace setup (monorepo)

If you use a Dart workspace, list every package directory under the root `pubspec.yaml`:

```yaml
environment:
  sdk: '>=3.9.0 <4.0.0'

workspace:
  - packages/core
  - packages/flutter
  - packages/my_feature
```

Each workspace member must declare `resolution: workspace` in its own `pubspec.yaml`.

## Your First Module

A module is a class that extends `Module`. Override `binds()` to register private dependencies and `exports()` to publish dependencies to importers.

```dart
import 'package:modularity_core/modularity_core.dart';

class AuthModule extends Module {
  @override
  void binds(Binder i) {
    // Private — only visible inside this module
    i.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
    i.registerFactory<LoginUseCase>(() => LoginUseCase(i.get<AuthRepository>()));
  }

  @override
  void exports(Binder i) {
    // Public — visible to modules that import AuthModule
    i.registerLazySingleton<AuthService>(() => AuthService(i.get<AuthRepository>()));
  }

  @override
  Future<void> onInit() async {
    // Runs after binds/exports, after all imports are loaded
  }
}
```

### Registration methods

| Method | Behaviour |
|--------|-----------|
| `registerLazySingleton<T>(() => ...)` | Created once on first `get<T>()` call |
| `registerFactory<T>(() => ...)` | New instance on every `get<T>()` call |
| `registerSingleton<T>(instance)` | Eagerly registered, always returns the same instance |

## Wiring the App

Three widgets connect modules to the Flutter tree:

1. **`ModularityRoot`** — top-level `InheritedWidget` that holds the global module registry and `BinderFactory`.
2. **`ModuleScope`** — manages the lifecycle of a single module.
3. **`Modularity.observer`** — `RouteObserver` that drives `routeBound` retention.

```dart
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      defaultLoadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
      defaultErrorBuilder: (_, error, retry) => Center(
        child: TextButton(onPressed: retry, child: Text('Retry: $error')),
      ),
      child: MaterialApp(
        navigatorObservers: [Modularity.observer],
        home: ModuleScope<AuthModule>(
          module: AuthModule(),
          child: const LoginPage(),
        ),
      ),
    );
  }
}
```

`ModularityRoot` must sit above any `ModuleScope` in the widget tree. `Modularity.observer` is required for `routeBound` retention to detect route pops.

## Accessing Dependencies

Inside the subtree of a `ModuleScope`, use `ModuleProvider.of(context)` to get the module's `Binder`:

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

### Available lookup methods

| Method | Returns | Behaviour |
|--------|---------|-----------|
| `get<T>()` | `T` | Throws `DependencyNotFoundException` if not found |
| `tryGet<T>()` | `T?` | Returns `null` if not found |
| `parent<T>()` | `T` | Searches parent scope only, throws if not found |
| `tryParent<T>()` | `T?` | Searches parent scope only, returns `null` |

### Resolution order

When you call `get<T>()`, the binder searches in this order:

1. **Local** — private and public registrations of the current module.
2. **Imports** — public exports of imported modules.
3. **Parent** — the binder of the nearest parent `ModuleScope` in the widget tree.

If the type is not found at any level, a `DependencyNotFoundException` is thrown with the list of available types for debugging.

### Accessing the Module instance

```dart
final authModule = ModuleProvider.moduleOf<AuthModule>(context);
```

This returns the concrete `Module` instance managed by the nearest `ModuleScope`.

## Lifecycle Hooks

Every module follows a deterministic lifecycle driven by `ModuleController`:

```
initial -> loading -> loaded
                  \-> error
loaded -> disposed
```

### Hooks

| Hook | When it runs |
|------|-------------|
| `binds(Binder i)` | Synchronously, after imports are resolved |
| `exports(Binder i)` | Synchronously, right after `binds()` |
| `onInit()` | Async, after binds/exports complete |
| `onDispose()` | When the module controller is disposed |

### ModuleStatus stream

`ModuleController` exposes a broadcast `Stream<ModuleStatus>` with values:

- `ModuleStatus.initial` — just created
- `ModuleStatus.loading` — `onInit()` is running
- `ModuleStatus.loaded` — ready to use
- `ModuleStatus.error` — `onInit()` threw
- `ModuleStatus.disposed` — cleaned up

### Loading and error builders

`ModuleScope` renders different widgets depending on the current status:

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

If no builders are provided, `ModuleScope` falls back to the defaults registered on `ModularityRoot`. If none exist there either, a plain `Text('Loading...')` or error column is shown.

### Retry on error

The `retry` callback passed to `errorBuilder` disposes the failed controller and creates a fresh one, re-running the full initialization cycle.
