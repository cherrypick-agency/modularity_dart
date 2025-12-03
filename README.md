# Modularity Framework

![coverage](https://img.shields.io/badge/coverage-61.4%25-yellow)

<img alt="image" src="https://github.com/user-attachments/assets/a5965bcc-681c-48ea-933d-a242d05b7163" />


A modular architecture framework for Flutter applications based on Clean Architecture & SOLID principles. Designed for enterprise-scale apps requiring strict isolation, testability, and a predictable lifecycle.

Repository: [github.com/cherrypick-agency/modularity_dart](https://github.com/cherrypick-agency/modularity_dart)

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
- **Retention Policies**: Control module lifetime (`RouteBound`, `KeepAlive`, `Strict`).
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
  void binds(Binder i) {
    // Private: Implementation details
    i.singleton<AuthRepository>(() => AuthRepositoryImpl());
  }

  @override
  void exports(Binder i) {
    // Public: Exposed API
    i.singleton<AuthService>(() => AuthService(i.get()));
  }
  
  @override
  Future<void> onInit() async {
    // Safe to use imports here - they are guaranteed to be ready
    await i.get<AuthService>().initialize();
  }
}
```

> **Prefer code generation?** If you'd rather use `injectable` for auto-wiring, see [modularity_injectable](packages/modularity_injectable/README.md). It's entirely optional — manual registration works great for most projects.

### 2. Initialize Root

```dart
void main() {
  runApp(ModularityRoot(
    child: MaterialApp(
      home: ModuleScope(
        module: AppModule(),
        child: HomePage(),
      ),
    ),
  ));
}
```

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

Need to inspect which dependencies a real module contributes? After the controllers finish initialization you can dump the binder to see both private and exported tokens (plus imported scopes):

```dart
final registry = <Type, ModuleController>{};

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
