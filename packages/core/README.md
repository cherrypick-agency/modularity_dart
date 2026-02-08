# modularity_core

[![pub package](https://img.shields.io/pub/v/modularity_core.svg)](https://pub.dev/packages/modularity_core)
[![pub points](https://img.shields.io/pub/points/modularity_core)](https://pub.dev/packages/modularity_core/score)

Core implementation of the Modularity framework, providing Dependency Injection (DI) container and Module Lifecycle management.

## Features

- **SimpleBinder**: A lightweight, platform-agnostic DI container
- **ModuleController**: Manages module lifecycle (init, dispose, hot reload)
- **Scoped Injection**: Hierarchical injectors with parent/child scopes
- **Import/Export System**: Clean separation between public and private dependencies
- **Circular Dependency Detection**: Prevents infinite loops in module graphs

## Installation

```yaml
dependencies:
  modularity_core: ^0.2.0
```

## Usage

### Defining a Module

```dart
import 'package:modularity_core/modularity_core.dart';

class AuthModule extends Module {
  @override
  void binds(Binder binder) {
    // Private dependencies (internal to module)
    binder.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
    binder.registerLazySingleton<AuthService>(
      () => AuthService(binder.get<AuthRepository>()),
    );
  }
  
  @override
  void exports(Binder binder) {
    // Public dependencies (available to importers)
    binder.registerLazySingleton<AuthService>(() => binder.get<AuthService>());
  }
}
```

### Using ModuleController

```dart
void main() async {
  final registry = <ModuleRegistryKey, ModuleController>{};
  
  final controller = ModuleController(AuthModule());
  
  await controller.initialize(registry);
  
  final authService = controller.binder.get<AuthService>();
  
  // Cleanup
  await controller.dispose();
}
```

### Module Imports

```dart
class ProfileModule extends Module {
  @override
  List<Module> get imports => [AuthModule()];
  
  @override
  List<Type> get expects => [AuthService]; // Validates imports
  
  @override
  void binds(Binder binder) {
    final authService = binder.get<AuthService>(); // From AuthModule
    binder.registerLazySingleton<ProfileService>(
      () => ProfileService(authService),
    );
  }
}
```

### Lifecycle Hooks

```dart
class MyModule extends Module {
  @override
  void binds(Binder binder) { /* ... */ }
  
  @override
  Future<void> onInit() async {
    // Called after binds() and exports()
    print('Module initialized');
  }
  
  @override
  Future<void> onDispose() async {
    // Called on dispose
    print('Module disposed');
  }
}
```

### Hot Reload Support

```dart
// Rebind all dependencies without recreating the controller
controller.hotReload();
```

Behind the scenes `ModuleController` switches the underlying binder into
`RegistrationStrategy.preserveExisting`, so singleton instances survive the
rebind while factories are refreshed with the latest code.

### Scoped overrides

Use `ModuleOverrideScope` when you need to override dependencies for imported
modules only during tests or hot reload:

```dart
final overrides = ModuleOverrideScope(children: {
  AuthModule: ModuleOverrideScope(
    selfOverrides: (binder) {
      binder.registerLazySingleton<AuthApi>(() => FakeAuthApi());
    },
  ),
});

await testModule(
  DashboardModule(),
  (module, binder) {
    // ...
  },
  overrideScope: overrides,
);
```

Overrides run after `binds` and before `exports`, and they are re-applied
automatically during hot reload.

### Interceptors

```dart
class LoggingInterceptor implements ModuleInterceptor {
  @override
  void onInit(Module module) => print('Init: ${module.runtimeType}');
  
  @override
  void onLoaded(Module module) => print('Loaded: ${module.runtimeType}');
  
  @override
  void onError(Module module, Object error) => print('Error: $error');
  
  @override
  void onDispose(Module module) => print('Disposed: ${module.runtimeType}');
}

final controller = ModuleController(
  MyModule(),
  interceptors: [LoggingInterceptor()],
);
```

## SimpleBinder API

| Method | Description |
|--------|-------------|
| `registerFactory<T>()` | New instance each call |
| `registerLazySingleton<T>()` | Single instance, created on first access |
| `registerSingleton<T>()` | Single instance, created immediately |
| `get<T>()` | Get dependency (throws if not found) |
| `tryGet<T>()` | Get dependency (returns null if not found) |
| `parent<T>()` | Get from parent scope only |

## License

MIT License - see [LICENSE](LICENSE) for details.
