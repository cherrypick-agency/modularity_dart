# Module Architecture

Visibility control, imports, parent scope chaining, the `expects` contract, configurable modules, and `submodules` vs `imports`.

## Private vs Public Dependencies

Each module has two scopes managed by `ExportableBinder`:

```dart
class NetworkModule extends Module {
  @override
  void binds(Binder i) {
    // Private -- invisible to importers
    i.registerLazySingleton<HttpInterceptor>(() => LoggingInterceptor());
    i.registerLazySingleton<HttpClient>(
      () => HttpClient(interceptor: i.get<HttpInterceptor>()),
    );
  }

  @override
  void exports(Binder i) {
    // Public -- the only surface importers can see
    i.registerLazySingleton<ApiClient>(
      () => ApiClient(http: i.get<HttpClient>()),
    );
  }
}
```

After `exports()` completes, the public scope is **sealed**. Further export registrations throw `ModuleConfigurationException`.

::: tip
When module A imports module B, only B's `exports()` types are visible to A. Everything in B's `binds()` stays private.
:::

## Module Imports

Override the `imports` getter to declare runtime dependencies. `GraphResolver` initializes all imports **concurrently** before calling the importing module's `binds()`.

```dart
class ProfileModule extends Module {
  @override
  List<Module> get imports => [AuthModule(), NetworkModule()];

  @override
  void binds(Binder i) {
    i.registerFactory<ProfileRepository>(
      () => ProfileRepository(
        auth: i.get<AuthService>(),   // from AuthModule.exports()
        api: i.get<ApiClient>(),      // from NetworkModule.exports()
      ),
    );
  }
}
```

### Graph Resolution

1. `GraphResolver.resolveAndInitImports()` processes `module.imports`.
2. Each import initializes **concurrently** via `Future.wait`.
3. Same module type imported by multiple branches is **deduplicated** -- first creator wins, others await.
4. **Circular dependencies** (`A -> B -> A`) throw `CircularDependencyException` with the full chain.
5. Resolved binders are injected via `binder.addImports()`.

### Diamond Dependencies

If B and C both import D, only one D controller is created. Both share it from the global registry.

## Parent Scope Chaining

Nested `ModuleScope` widgets form an implicit parent chain. The child's `SimpleBinder` receives the parent binder as a fallback.

```dart
// Widget tree:
// ModuleScope<AppModule>
//   +-- ModuleScope<FeatureModule>
//         +-- FeatureWidget
```

```dart
class FeatureModule extends Module {
  @override
  void binds(Binder i) {
    i.registerFactory<FeatureService>(
      () => FeatureService(analytics: i.parent<AnalyticsService>()),
    );
  }
}
```

| Method | Scope |
|--------|-------|
| `get<T>()` / `tryGet<T>()` | Local -> Imports -> Parent (full chain) |
| `parent<T>()` / `tryParent<T>()` | Parent scope only |

Use `parent<T>()` when you need to **skip** local and import scopes explicitly -- for example, to avoid shadowing a type that exists in both scopes.

## The `expects` Contract

Declare types that **must** exist before the module initializes. Missing types fail fast with `ModuleConfigurationException` instead of a late `DependencyNotFoundException`.

```dart
class OrderModule extends Module {
  @override
  List<Type> get expects => [AuthService, ApiClient];

  @override
  List<Module> get imports => [PaymentModule()];

  @override
  void binds(Binder i) {
    i.registerFactory<OrderService>(
      () => OrderService(
        auth: i.get<AuthService>(),
        api: i.get<ApiClient>(),
        payment: i.get<PaymentService>(),
      ),
    );
  }
}
```

::: warning Validation timing
`expects` is checked **after** imports are resolved but **before** `binds()` runs. The check uses `binder.contains(type)`, which searches imports + parent. Expected types can come from either source.
:::

Use `expects` when a module depends on types provided by a **parent scope** rather than its own imports.

## Configurable Modules

Modules that need runtime parameters implement `Configurable<T>`. The `configure(T args)` method runs **before** `binds()`.

```dart
class UserProfileModule extends Module implements Configurable<String> {
  late final String _userId;

  @override
  void configure(String args) {
    _userId = args;
  }

  @override
  void binds(Binder i) {
    i.registerLazySingleton<UserRepository>(
      () => UserRepository(userId: _userId),
    );
  }
}
```

Pass arguments via `ModuleScope.args`:

```dart
ModuleScope<UserProfileModule>(
  module: UserProfileModule(),
  args: userId,
  child: const UserProfilePage(),
)
```

Full lifecycle order:

```
configure(args) -> imports resolved -> expects validated -> binds() -> exports() -> onInit()
```

If the wrong argument type is passed, `ModuleController` wraps the `TypeError` in a `ModuleLifecycleException`.

## Submodules vs Imports

| | `imports` | `submodules` |
|--|-----------|-------------|
| **Purpose** | Runtime DI | Static analysis and visualization |
| **Initialization** | Resolved by `GraphResolver` | Not initialized by the framework |
| **Binder access** | Public exports injected into importer | No binder connection |
| **Use case** | Need types from another module | Document feature composition for tooling |

### imports -- runtime DI

```dart
class CheckoutModule extends Module {
  @override
  List<Module> get imports => [CartModule(), PaymentModule()];

  @override
  void binds(Binder i) {
    i.registerFactory<CheckoutService>(
      () => CheckoutService(
        cart: i.get<CartService>(),
        payment: i.get<PaymentService>(),
      ),
    );
  }
}
```

### submodules -- structural composition

```dart
class AppModule extends Module {
  @override
  List<Module> get submodules => [
    AuthModule(),
    ProfileModule(),
    SettingsModule(),
  ];

  @override
  void binds(Binder i) {
    i.registerSingleton<AppConfig>(AppConfig());
  }
}
```

Submodules are consumed by `modularity_cli` tools (`ModuleBindingsAnalyzer`, `GraphVisualizer`) for dependency graph visualization. They should use `Configurable` instead of constructor arguments so tooling can instantiate them cleanly.

A module can appear in both `imports` and `submodules` if needed.

## Visualizing the Module Graph

The `modularity_cli` package can generate interactive dependency graphs from your module tree. `GraphVisualizer` analyzes `binds()`, `exports()`, `imports`, and `submodules` using a `RecordingBinder` (no real instances are created) and opens the result in a browser.

```dart
import 'package:modularity_cli/modularity_cli.dart';

void main() async {
  // Static Graphviz DOT diagram (default)
  await GraphVisualizer.visualize(AppModule());

  // Interactive AntV G6 diagram with drag, zoom, and tooltips
  await GraphVisualizer.visualize(AppModule(), renderer: GraphRenderer.g6);
}
```

Each node shows the module name, its public/private registrations with their kind (singleton, factory, instance), and any `expects` declarations. Edges are labeled `imports` (dashed) or `owns` (diamond) for submodules.

Add `modularity_cli` as a dev dependency and run the script with `dart run`:

```yaml
dev_dependencies:
  modularity_cli: ^0.2.0
```

```bash
dart run tool/visualize_graph.dart
```
