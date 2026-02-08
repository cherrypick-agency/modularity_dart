# modularity_get_it

[![pub package](https://img.shields.io/pub/v/modularity_get_it.svg)](https://pub.dev/packages/modularity_get_it)
[![pub points](https://img.shields.io/pub/points/modularity_get_it)](https://pub.dev/packages/modularity_get_it/score)

GetIt adapter for the Modularity framework. Allows using [GetIt](https://pub.dev/packages/get_it) as the backing DI container.

## Features

- **GetItBinder**: Implementation of `ExportableBinder` that delegates to GetIt
- **GetItBinderFactory**: Factory to create GetIt binders with parent scope support
- **Dual Scopes**: Separate private and public scopes for proper module isolation
- **Hot Reload Support**: Reset and rebind without creating new instances

## Installation

```yaml
dependencies:
  modularity_get_it: ^0.2.0
  modularity_core: ^0.2.0
```

## Usage

### Basic Setup

```dart
import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_get_it/modularity_get_it.dart';

class MyModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<MyService>(() => MyServiceImpl());
  }
  
  @override
  void exports(Binder binder) {
    binder.registerLazySingleton<MyService>(() => binder.get<MyService>());
  }
}

void main() async {
  final controller = ModuleController(
    MyModule(),
    binderFactory: const GetItBinderFactory(),
  );
  
  await controller.initialize({});
  
  final service = controller.binder.get<MyService>();
}
```

### Accessing GetIt Directly

```dart
final binder = GetItBinder();

// Access internal (private) container
final internalGetIt = binder.internalContainer;

// Access public (exported) container  
final publicGetIt = binder.publicContainer;
```

### Debug Graph

```dart
final binder = controller.binder as GetItBinder;
print(binder.debugGraph(includeImports: true));
```

## API Reference

### GetItBinder

| Method | Description |
|--------|-------------|
| `registerFactory<T>()` | Register a factory (new instance each time) |
| `registerLazySingleton<T>()` | Register a lazy singleton |
| `registerSingleton<T>()` | Register an eager singleton |
| `get<T>()` | Get dependency (throws if not found) |
| `tryGet<T>()` | Get dependency (returns null if not found) |
| `tryGetPublic<T>()` | Get only from public/exported scope |

### GetItBinderFactory

Creates `GetItBinder` instances with optional parent scope support.

```dart
const factory = GetItBinderFactory();
final binder = factory.create(); // No parent
final childBinder = factory.create(parentBinder); // With parent
```

## License

MIT License - see [LICENSE](LICENSE) for details.
