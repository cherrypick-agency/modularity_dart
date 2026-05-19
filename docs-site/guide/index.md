# Guide

This guide covers the main path for adopting Modularity in a Flutter app: install the runtime packages, define feature modules, mount them with `ModuleScope`, and use the API reference when you need exact class-level details.

## Before You Start

- Dart SDK `>=3.9.0 <4.0.0`.
- Flutter `>=3.29.0` when using `modularity_flutter`.
- A `RouteObserver<ModalRoute<dynamic>>` if you use the default `routeBound` retention policy.

## Install

For a Flutter app:

```bash
flutter pub add modularity_flutter modularity_core
flutter pub add --dev modularity_test
```

For pure Dart package contracts or custom adapters:

```bash
dart pub add modularity_contracts modularity_core
```

`modularity_flutter` depends on `modularity_core` and `modularity_contracts`, but adding `modularity_core` explicitly keeps module code imports clear.

## Minimal Flow

1. Create a `Module` and register private dependencies in `binds()`.
2. Put only the public surface in `exports()`.
3. Wrap the app with `ModularityRoot`.
4. Mount a feature with `ModuleScope`.
5. Resolve dependencies with `ModuleProvider.of(context).get<T>()`.

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<AuthService>(
      () => AuthService(i.get<AuthRepository>()),
    );
  }
}
```

```dart
final observer = RouteObserver<ModalRoute<dynamic>>();

ModularityRoot(
  observer: observer,
  child: MaterialApp(
    navigatorObservers: [observer],
    home: ModuleScope(
      module: AuthModule(),
      child: const HomePage(),
    ),
  ),
);
```

```dart
final auth = ModuleProvider.of(context).get<AuthService>();
```

## Reader Path

- [Getting Started](./modularity_workspace/getting-started.md) - install, first module, Flutter wiring, dependency lookup.
- [Module Architecture](./modularity_workspace/module-architecture.md) - imports, exports, parent scopes, `expects`, and `Configurable<T>`.
- [Routing Integration](./modularity_workspace/routing-integration.md) - GoRouter, AutoRoute, nested routes, tab layouts.
- [State Management](./modularity_workspace/state-management.md) - Bloc, Riverpod, MobX, and shared parent state.
- [Testing Modules](./modularity_workspace/testing-modules.md) - pure Dart module tests and widget integration tests.
- [Best Practices](./modularity_workspace/best-practices.md) - module sizing, boundaries, lifecycle, and common mistakes.

## API Overview

| Package | Use it for | Primary API |
|---------|------------|-------------|
| `modularity_contracts` | Shared abstractions | `Module`, `Binder`, `Configurable`, `ModuleInterceptor` |
| `modularity_core` | Runtime DI and lifecycle | `ModuleController`, `SimpleBinder`, `ModuleOverrideScope` |
| `modularity_flutter` | Widget integration | `ModularityRoot`, `ModuleScope`, `ModuleProvider` |
| `modularity_test` | Isolated module tests | `testModule`, `TestBinder` |
| `modularity_cli` | Graph analysis and visualization | `GraphVisualizer`, `GraphRenderer`, `ModuleBindingsAnalyzer` |
| `modularity_get_it` | GetIt-backed binder | `GetItBinder`, `GetItBinderFactory` |
| `modularity_injectable` | Injectable + GetIt bridge | `ModularityInjectableBridge`, `ModularityExportOnly` |

Use the [API Reference](/api/) for signatures and generated Dart docs. Use the guide pages for architectural rules and end-to-end examples.
