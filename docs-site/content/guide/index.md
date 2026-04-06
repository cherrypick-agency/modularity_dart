# Modularity Guide

Everything you need to build production Flutter apps with strict module boundaries, deterministic initialization, and flexible DI.

## Getting Started

### 1. Add Dependencies

```bash
flutter pub add modularity_flutter modularity_core
```

For testing:

```bash
flutter pub add --dev modularity_test
```

### 2. Define Your First Module

```dart
import 'package:modularity_core/modularity_core.dart';

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

### 3. Wire It Up

```dart
final observer = RouteObserver<ModalRoute<dynamic>>();

void main() {
  runApp(ModularityRoot(
    observer: observer,
    child: MaterialApp(
      navigatorObservers: [observer],
      home: ModuleScope(module: AppModule(), child: const HomePage()),
    ),
  ));
}
```

### 4. Use Dependencies

```dart
final auth = ModuleProvider.of(context).get<AuthService>();
```

## Key Concepts

| Concept | What it does |
|---------|-------------|
| **Module** | Encapsulates a feature: private binds, public exports, async init |
| **Binder** | DI container with factory, singleton, and lazy singleton registration |
| **ModuleScope** | Widget that manages module lifecycle tied to the widget tree |
| **ModularityRoot** | Top-level provider with RouteObserver and interceptors |
| **ModuleProvider** | InheritedWidget to resolve dependencies from nearest scope |

## Module Lifecycle

Every module follows a deterministic state machine:

```
initial -> loading -> loaded -> disposed
              |
              v
            error (retryable)
```

- **initial**: Module created, not yet initialized
- **loading**: Imports resolving concurrently via DAG, then `binds()` and `exports()` run
- **loaded**: `onInit()` completed, module ready for use
- **disposed**: Module cleaned up, all resources released

## Visibility Rules

```dart
class PaymentModule extends Module {
  @override
  void binds(Binder i) {
    // Private - only PaymentModule can see these
    i.registerFactory<StripeClient>(() => StripeClient());
    i.registerLazySingleton<PaymentRepo>(() => PaymentRepo(i.get()));
  }

  @override
  void exports(Binder i) {
    // Public - parent and sibling modules can access
    i.registerLazySingleton<PaymentService>(
      () => PaymentService(i.get<PaymentRepo>()),
    );
  }
  // After exports() the public scope is sealed
}
```

## Router Integration

Works with **any** router. Here's GoRouter:

```dart
GoRoute(
  path: '/product/:id',
  builder: (context, state) => ModuleScope(
    module: ProductModule(),
    args: state.pathParameters['id'],
    child: const ProductPage(),
  ),
)
```

## Testing

Unit test modules in pure Dart - no Flutter, no `pumpWidget`:

```dart
test('PaymentModule exports PaymentService', () async {
  await testModule(PaymentModule(), (module, binder) {
    expect(binder.hasSingleton<PaymentService>(), isTrue);
  });
});
```

## Next Steps

- Browse the [API Reference](/api/) for full documentation
- Check the sidebar for advanced topics: overrides, retention, interceptors, graph visualization
