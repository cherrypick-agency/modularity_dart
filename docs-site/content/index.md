---
layout: home
title: "Modularity"
description: "Modular architecture framework for Flutter - strict DI, deterministic lifecycle, zero initialization hell"
hero:
  name: "Modularity"
  text: Modular Architecture for Flutter
  tagline: Strict dependency injection, deterministic lifecycle, and enterprise-grade module isolation. Works with any router and any state manager.
  actions:
    - theme: brand
      text: Quick Start
      link: /guide/
    - theme: alt
      text: API Reference
      link: /api/
features:
  - icon: "\U0001F9E9"
    title: Zero Initialization Hell
    details: Modules initialize in dependency order via concurrent DAG resolution. onInit is guaranteed to run after all imports are ready - no race conditions, no manual ordering.
  - icon: "\U0001F512"
    title: Strict DI Boundaries
    details: Private binds stay private, public exports are sealed after registration. No hidden globals, no implicit access. Every dependency is explicit and type-safe.
  - icon: "\U0001F504"
    title: Formal Lifecycle
    details: "State machine with clear transitions: initial, loading, loaded, disposed. Automatic disposal on route pop, configurable retention policies (routeBound, keepAlive, strict)."
  - icon: "\U0001F6E0\uFE0F"
    title: Router & State Agnostic
    details: Works with GoRouter, AutoRoute, Navigator 1.0. Integrates with Bloc, Riverpod, MobX, or none. Modularity handles DI and lifecycle - you pick the rest.
---

## Install

```bash
flutter pub add modularity_flutter modularity_core
```

## Quick Start

<Tabs defaultValue="module">
  <TabItem label="Define Module" value="module">

Each feature gets its own module with private implementation and public exports. Dependencies are explicit - no globals, no magic.

```dart
import 'package:modularity_core/modularity_core.dart';

class AuthModule extends Module {
  @override
  void binds(Binder i) {
    // Private - only this module can access
    i.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
    i.registerFactory<LoginUseCase>(
      () => LoginUseCase(i.get<AuthRepository>()),
    );
  }

  @override
  void exports(Binder i) {
    // Public - available to parent and sibling modules
    i.registerLazySingleton<AuthService>(
      () => AuthService(i.get<AuthRepository>()),
    );
  }
}
```

  </TabItem>
  <TabItem label="Wire the App" value="wire">

Wrap your app with `ModularityRoot` and place `ModuleScope` where you need modules. Loading and error states are handled automatically.

```dart
final observer = RouteObserver<ModalRoute<dynamic>>();

void main() {
  runApp(ModularityRoot(
    observer: observer,
    defaultLoadingBuilder: (_) =>
        const Center(child: CircularProgressIndicator()),
    child: MaterialApp(
      navigatorObservers: [observer],
      home: ModuleScope(
        module: AppModule(),
        child: const HomePage(),
      ),
    ),
  ));
}
```

  </TabItem>
  <TabItem label="Use in UI" value="use">

Access dependencies from the nearest module scope. Type-safe, no string keys, no service locators.

```dart
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = ModuleProvider.of(context).get<AuthService>();
    return Scaffold(
      body: Center(
        child: Text('Logged in: ${auth.isLoggedIn}'),
      ),
    );
  }
}
```

  </TabItem>
  <TabItem label="Test" value="test">

Test modules in pure Dart - no Flutter, no widget pumping. Verify registrations and resolutions directly.

```dart
import 'package:modularity_test/modularity_test.dart';

test('AuthModule registers expected deps', () async {
  await testModule(AuthModule(), (module, binder) {
    expect(binder.hasSingleton<AuthRepository>(), isTrue);
    expect(binder.hasSingleton<AuthService>(), isTrue);

    final repo = binder.get<AuthRepository>();
    expect(repo, isA<AuthRepositoryImpl>());
  });
});
```

  </TabItem>
</Tabs>

## Packages

| Package | pub.dev | Description |
|---------|---------|-------------|
| [modularity_contracts](/api/modularity_contracts/library) | `modularity_contracts` | Zero-dependency interfaces: Module, Binder, exceptions |
| [modularity_core](/api/modularity_core/library) | `modularity_core` | DI container, lifecycle state machine, DAG resolver |
| [modularity_flutter](/api/modularity_flutter/library) | `modularity_flutter` | Flutter widgets: ModularityRoot, ModuleScope, ModuleProvider |
| [modularity_test](/api/modularity_test/library) | `modularity_test` | Unit test helpers: testModule, TestBinder |
| [modularity_cli](/api/modularity_cli/library) | `modularity_cli` | Graphviz and interactive dependency graph visualization |
| [modularity_get_it](/api/modularity_get_it/library) | `modularity_get_it` | GetIt adapter for migration from existing GetIt projects |

## Why Modularity?

Most Flutter DI solutions give you a container but leave initialization order, scope boundaries, and lifecycle management to you. As apps grow, this leads to:

- **Initialization hell** - services depend on other services that aren't ready yet
- **Hidden globals** - anything can access anything, making refactoring risky
- **No formal lifecycle** - disposal is manual and error-prone
- **Router lock-in** - DI is tightly coupled to a specific navigation library

Modularity solves all four with a formal module system inspired by NestJS and Angular, adapted for Flutter's widget tree.

## How It Compares

| Feature | Modularity | flutter_modular | Provider / Riverpod |
|---------|-----------|-----------------|---------------------|
| Module definition | Pure Dart class + state machine | Class with routes (router-coupled) | No formal module concept |
| Initialization | Concurrent DAG, deterministic | Lazy or navigation-based | Lazy or widget-mount |
| Visibility | Explicit binds/exports, sealed | Implicit parent access | Global or scoped |
| Lifecycle | Formal state machine | Bound to router | Bound to widget tree |
| Router coupling | None - works with any router | Strong - router is core | Indirect |
| Unit testing | Pure Dart, no Flutter needed | Integration-focused | Requires pumpWidget |

## Advanced Features

### Configurable Modules

Pass runtime arguments to modules - perfect for detail screens, feature flags, or environment config.

```dart
class ProductModule extends Module implements Configurable<String> {
  late String productId;

  @override
  void configure(String args) => productId = args;
}

// In your route:
ModuleScope(module: ProductModule(), args: productId, child: ...)
```

### Hierarchical Overrides

Swap dependencies for testing, feature flags, or A/B experiments without changing module code.

```dart
final overrides = ModuleOverrideScope(
  children: {
    AuthModule: ModuleOverrideScope(
      selfOverrides: (binder) {
        binder.registerLazySingleton<AuthService>(() => MockAuthService());
      },
    ),
  },
);

ModuleScope(module: AppModule(), overrideScope: overrides, child: ...)
```

### Dependency Graph Visualization

See your entire module hierarchy as an interactive diagram. Find circular dependencies and hidden coupling before they become problems.

```dart
import 'package:modularity_cli/modularity_cli.dart';

void main() async {
  await GraphVisualizer.visualize(AppModule(), renderer: GraphRenderer.g6);
}
```

## Learn More

- [Guide](/guide/) - Architecture overview and recipes
- [API Reference](/api/) - Full API documentation for all packages
- [GitHub](https://github.com/cherrypick-agency/modularity_dart) - Source code and issues
