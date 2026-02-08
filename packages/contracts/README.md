# modularity_contracts

Zero-dependency interfaces for the Modularity framework.

This package defines the core contracts (`Module`, `Binder`, `ExportableBinder`, `DisposableBinder`) used by `modularity_core` and other packages.
It contains no implementation logic and has no dependencies, making it lightweight and easy to implement.

## Usage

Extend `Module` to define a feature module:

```dart
import 'package:modularity_contracts/modularity_contracts.dart';

class MyModule extends Module {
  @override
  void binds(Binder binder) {
    // Register dependencies
    binder.singleton(() => MyService());
  }
}
```
