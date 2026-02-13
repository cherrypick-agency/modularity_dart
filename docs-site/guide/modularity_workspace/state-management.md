# State Management Integration

Modularity handles DI and lifecycle. State management libraries handle reactivity. They compose cleanly: register reactive objects in `binds()`, resolve them via `ModuleProvider.of(context)`, and feed them to your chosen state library.

## Core Principle

```mermaid
flowchart LR
    subgraph Modularity
        DI[Binder]
    end
    subgraph "State Layer"
        B[Bloc/Cubit]
        R[Riverpod]
        M[MobX Store]
    end
    DI -->|provides repos/services| B
    DI -->|provides repos/services| R
    DI -->|provides repos/services| M
```

The pattern is always the same:

1. Register state objects in `Module.binds()`.
2. Resolve them via `ModuleProvider.of(context).get<T>()`.
3. Feed them into the state library's provider or observer widget.

`ModuleScope` owns creation and disposal. The state library owns reactivity and UI rebuilds. Do not mix these responsibilities.

## Bloc / Cubit

### Register in binds()

Use `registerFactory` for fresh instances per consumer, `registerLazySingleton` to share one across the scope:

```dart
class CounterModule extends Module {
  @override
  void binds(Binder i) {
    i.registerFactory<CounterCubit>(() => CounterCubit());
  }
}
```

### Resolve and provide

Resolve the Cubit from `ModuleProvider` and hand it to `BlocProvider`:

```dart
class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ModuleProvider.of(
        context,
        listen: false,
      ).get<CounterCubit>(),
      child: const CounterView(),
    );
  }
}
```

`listen: false` avoids rebuilding `CounterPage` when the binder changes. `BlocProvider` owns the Cubit lifecycle from this point -- but the Cubit's *dependencies* are managed by Modularity.

### Consume normally

Below `BlocProvider`, use `BlocBuilder` and `context.read<T>()` as usual:

```dart
class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: BlocBuilder<CounterCubit, int>(
          builder: (context, count) => Text('Count: $count'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<CounterCubit>().increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### Bloc with dependencies

When a Bloc needs injected services, register them in `binds()` and resolve inside the factory:

```dart
class OrderModule extends Module {
  @override
  List<Type> get expects => [AuthService];

  @override
  void binds(Binder i) {
    i.registerLazySingleton<OrderRepository>(
      () => OrderRepositoryImpl(),
    );
    i.registerFactory<OrderCubit>(
      () => OrderCubit(
        repository: i.get<OrderRepository>(),
        auth: i.get<AuthService>(),
      ),
    );
  }
}
```

`expects` declares that `AuthService` must exist in a parent scope. Initialization fails fast if the dependency is missing.

### Multi-Bloc module

A single module can register multiple Cubits/Blocs. Provide them to the tree with `MultiBlocProvider`:

```dart
class DashboardModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<UserCubit>(
      () => UserCubit(i.get<UserRepository>()),
    );
    i.registerLazySingleton<NotificationCubit>(
      () => NotificationCubit(i.get<NotificationService>()),
    );
  }
}
```

```dart
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final binder = ModuleProvider.of(context, listen: false);
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => binder.get<UserCubit>()),
        BlocProvider(create: (_) => binder.get<NotificationCubit>()),
      ],
      child: const DashboardView(),
    );
  }
}
```

### Bloc with exports

Keep the repository private, export only the public-facing service:

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
    i.registerLazySingleton<AuthBloc>(
      () => AuthBloc(i.get<AuthRepository>()),
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

The repository stays private to `AuthModule`. Only `AuthService` is visible to importing modules.

### Dispose cleanup

For Blocs that manage streams or subscriptions, clean up in `onDispose()`:

```dart
class StreamModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<DataStreamCubit>(
      () => DataStreamCubit(i.get<DataSource>()),
    );
  }

  @override
  void onDispose() {
    // The Binder is disposed automatically by ModuleController.
    // Use onDispose for non-DI cleanup: canceling timers,
    // closing WebSocket connections, etc.
  }
}
```

### App wiring

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      child: MaterialApp(
        navigatorObservers: [Modularity.observer],
        home: ModuleScope(
          module: CounterModule(),
          child: const CounterPage(),
        ),
      ),
    );
  }
}
```

## Riverpod

Riverpod manages its own dependency graph. The integration pattern bridges Modularity's DI into Riverpod providers via overrides.

### Define providers with placeholder

Create providers that throw by default -- they will be overridden at runtime:

```dart
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('Override in ModuleScope');
});

final counterProvider = StateProvider<int>((ref) => 0);
```

### Module registration

```dart
class CounterModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<AuthService>(
      () => AuthService('api-token'),
    );
  }
}
```

### Bridge via ProviderScope.overrides

Resolve from the binder and inject into Riverpod:

```dart
class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final binder = ModuleProvider.of(context);
    final authService = binder.get<AuthService>();

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
      ],
      child: const CounterView(),
    );
  }
}
```

::: warning
Place `ProviderScope` **inside** `ModuleScope` so the binder is available when overrides are built. If `ProviderScope` is above `ModuleScope`, `ModuleProvider.of(context)` will throw.
:::

### Consume normally

```dart
class CounterView extends ConsumerWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    final auth = ref.watch(authServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Token: ${auth.token}')),
      body: Center(child: Text('Count: $count')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(counterProvider.notifier).state++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

This pattern keeps Riverpod providers pure and testable -- they declare their dependency contract, and `ModuleScope` satisfies it at runtime. In tests, provide mocks directly without Modularity.

## MobX

MobX stores are plain Dart objects with observables. Register them in `binds()` and resolve with `ModuleProvider.of(context)`. No extra provider widget is needed -- `Observer` from `flutter_mobx` rebuilds whenever any accessed observable changes.

### Register stores

Register stores as singletons so the same reactive state is shared across the module:

```dart
class RootModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<AuthStore>(() => AuthStore());
    i.registerLazySingleton<CartStore>(() => CartStore());
  }
}
```

### Resolve and observe

Resolve stores from the binder and wrap reactive reads in `Observer`:

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authStore = ModuleProvider.of(context).get<AuthStore>();

    return Scaffold(
      body: Center(
        child: Observer(
          builder: (_) {
            if (authStore.isLoading) {
              return const CircularProgressIndicator();
            }
            return ElevatedButton(
              onPressed: () => authStore.login('user', 'password'),
              child: const Text('Login'),
            );
          },
        ),
      ),
    );
  }
}
```

### Stores with module dependencies

A store registered in a child module can depend on services from parent scopes:

```dart
class HomeModule extends Module {
  @override
  List<Type> get expects => [CartStore];

  @override
  void binds(Binder i) {
    i.registerLazySingleton<ProductStore>(() => ProductStore());
  }
}
```

Resolve both the local and parent-scoped stores in the page. Use `didChangeDependencies()` because `ModuleProvider.of(context)` depends on `InheritedWidget`, which is not available during `initState()`:

```dart
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ProductStore productStore;
  late final CartStore cartStore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final binder = ModuleProvider.of(context);
    productStore = binder.get<ProductStore>();
    cartStore = binder.get<CartStore>();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => ListView.builder(
        itemCount: productStore.products.length,
        itemBuilder: (context, index) {
          final product = productStore.products[index];
          return ListTile(
            title: Text(product.name),
            trailing: IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              onPressed: () => cartStore.add(product),
            ),
          );
        },
      ),
    );
  }
}
```

### Configurable modules with MobX

Pass runtime data into a module via `Configurable<T>`:

```dart
class ProductDetailsModule extends Module
    implements Configurable<Product> {
  late Product _product;

  @override
  void configure(Product args) => _product = args;

  @override
  List<Type> get expects => [CartStore];

  @override
  void binds(Binder i) {
    i.registerSingleton<Product>(_product);
  }
}
```

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ModuleScope(
      module: ProductDetailsModule(),
      args: product,
      child: const ProductDetailsPage(),
    ),
  ),
);
```

## Cross-Module State Sharing

Share state across modules using scope chaining. Register shared state in a parent module and declare it in child modules via `expects`:

```
ModuleScope(RootModule)          <- registers AuthStore, CartStore
  +-- ModuleScope(HomeModule)     <- expects: [CartStore]
  +-- ModuleScope(CartModule)     <- expects: [CartStore]
  +-- ModuleScope(SettingsModule) <- expects: [AuthStore]
```

### Root module

```dart
class RootModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<AuthStore>(() => AuthStore());
    i.registerLazySingleton<CartStore>(() => CartStore());
  }
}
```

### Child module

```dart
class CartModule extends Module {
  @override
  List<Type> get expects => [CartStore];

  @override
  void binds(Binder i) {
    // CartStore comes from parent, no need to register it
  }
}
```

Any child module can call `ModuleProvider.of(context).get<CartStore>()` and receive the same singleton instance from `RootModule`.

### Resolution order

`get<T>()` searches: **private scope** -> **imports** (public exports) -> **parent scope**. Private registrations shadow parent bindings of the same type.

To explicitly access the parent's version when a local binding shadows it:

```dart
final parentCart = ModuleProvider.of(context).parent<CartStore>();
```

### Exported dependencies

For cross-module sharing between siblings (not parent-child), use `imports` and `exports()`:

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    // Private: only AuthModule can resolve this
    i.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(),
    );
  }

  @override
  void exports(Binder i) {
    // Public: available to importing modules
    i.registerLazySingleton<AuthService>(
      () => AuthService(i.get<AuthRepository>()),
    );
  }
}
```

Modules that import `AuthModule` can resolve `AuthService` but not `AuthRepository`.

## Tab Navigation with Shared State

Tabs that share state from a parent module:

```dart
class MainModule extends Module {
  @override
  List<Type> get expects => [AuthStore, CartStore];

  @override
  void binds(Binder i) {}
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ModuleScope(module: HomeModule(), child: const HomePage()),
          ModuleScope(module: CartModule(), child: const CartPage()),
          ModuleScope(
            module: SettingsModule(),
            child: const SettingsPage(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home), label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart), label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings), label: 'Settings',
          ),
        ],
      ),
    );
  }
}
```

Each tab has its own `ModuleScope` but shares `AuthStore` and `CartStore` from `RootModule` above.

## Choosing a Pattern

| Scenario | Recommendation |
|----------|---------------|
| Simple app, few screens | Modularity only, no extra state lib |
| Complex reactive UI | Modularity + Bloc or MobX |
| Existing Riverpod codebase | Bridge pattern: Modularity DI into Riverpod providers |
| Cross-module shared state | Register in parent `ModuleScope`, declare `expects` in children |
| Per-route ephemeral state | `registerFactory` in `binds()`, new instance each time |
| App-wide singleton | `registerLazySingleton` in root module's `binds()` |

## Summary

| State Library | Register in | Bridge widget | Consume with |
|---------------|------------|---------------|-------------|
| Bloc/Cubit | `binds()` | `BlocProvider(create: binder.get)` | `BlocBuilder`, `context.read` |
| Riverpod | `binds()` | `ProviderScope(overrides: [...])` | `ref.watch`, `ref.read` |
| MobX | `binds()` | None needed | `Observer(builder: ...)` |

All three follow the same flow:

1. Register in `binds()` (Modularity owns creation and disposal).
2. Resolve via `ModuleProvider.of(context).get<T>()`.
3. Feed to the state management layer's own provider/observer.

Modularity does not replace your state management library. It manages *when* reactive objects are created and destroyed, scoped to module boundaries. Your chosen library handles *how* the UI reacts to state changes.
