# Modularity Test

Testing utilities for the Modularity framework.

## Features

- **`testModule`**: A helper function to test module lifecycle and bindings in isolation.
- **`TestBinder`**: A `Binder` proxy that records all registrations and resolutions, allowing you to verify internal module state.

## Usage

### Testing a Module

Use `testModule` to instantiate a module, run its lifecycle (initialization), and verify its bindings.

```dart
import 'package:test/test.dart';
import 'package:modularity_test/modularity_test.dart';
import 'my_module.dart';

void main() {
  test('MyModule registers MyService', () async {
    await testModule(MyModule(), (module, binder) {
      // Verify registration type
      expect(binder.hasSingleton<MyService>(), isTrue);
      
      // Verify resolution
      final service = binder.get<MyService>();
      expect(service, isNotNull);
      
      // Verify that it was resolved
      expect(binder.wasResolved<MyService>(), isTrue);
    });
  });
}
```

### Mocking Dependencies

You can use `overrides` to replace real dependencies with mocks before the module initializes.

```dart
await testModule(
  MyModule(),
  (module, binder) {
    // ...
  },
  overrides: (binder) {
    binder.singleton<Api>(() => MockApi());
  },
);
```

