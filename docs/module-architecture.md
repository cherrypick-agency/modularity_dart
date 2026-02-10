# Module Architecture

This guide covers advanced module design: visibility control, imports, parent scope chaining, the `expects` contract, configurable modules, and the distinction between submodules and imports.

## Private vs Public Dependencies

Every module has two scopes managed by `ExportableBinder`:

- **Private** (`binds()`) — internal registrations visible only within the module.
- **Public** (`exports()`) — registrations visible to modules that import this one.

```dart
class NetworkModule extends Module {
  @override
  void binds(Binder i) {
    // Private: implementation detail, not accessible to importers
    i.registerLazySingleton<HttpInterceptor>(() => LoggingInterceptor());
    i.registerLazySingleton<HttpClient>(
      () => HttpClient(interceptor: i.get<HttpInterceptor>()),
    );
  }

  @override
  void exports(Binder i) {
    // Public: only the API surface is exposed
    i.registerLazySingleton<ApiClient>(
      () => ApiClient(http: i.get<HttpClient>()),
    );
  }
}
```

After `exports()` runs, the public scope is **sealed** — any attempt to register new exports throws a `ModuleConfigurationException`. This guarantees a stable public API surface at runtime.

### Lookup rules for importers

When module A imports module B, `A.get<T>()` can only see types registered in B's `exports()`. Types from B's `binds()` are invisible to A.

## Module Imports

Use the `imports` getter to declare runtime dependencies between modules. The `GraphResolver` initializes all imports **concurrently** before the importing module's `binds()` runs.

```dart
class ProfileModule extends Module {
  @override
  List<Module> get imports => [AuthModule(), NetworkModule()];

  @override
  void binds(Binder i) {
    // AuthService comes from AuthModule.exports()
    // ApiClient comes from NetworkModule.exports()
    i.registerFactory<ProfileRepository>(
      () => ProfileRepository(
        auth: i.get<AuthService>(),
        api: i.get<ApiClient>(),
      ),
    );
  }
}
```

### How graph resolution works

1. `GraphResolver.resolveAndInitImports()` iterates over `module.imports`.
2. Each import is resolved **concurrently** via `Future.wait`.
3. If two branches import the same module type, the first branch creates the controller and the second waits for it to finish (deduplication via the global registry).
4. **Circular dependencies** are detected immediately: if `A -> B -> A` is found, a `CircularDependencyException` is thrown with the full dependency chain.
5. After all imports are loaded, their binders are added via `binder.addImports()`, making their public exports available to the current module.

### Diamond dependencies

If module A imports B and C, and both B and C import D, only one instance of D's controller is created. Both B and C share the same resolved controller from the global registry.

## Parent Scope Chaining

When `ModuleScope` widgets are nested in the Flutter tree, each child module automatically gets a reference to the parent module's binder. This enables implicit scope chaining.

```dart
// Widget tree:
// ModuleScope<AppModule>
//   └── ModuleScope<FeatureModule>
//         └── FeatureWidget
```

Inside `FeatureModule`, you can access dependencies from `AppModule` using `parent<T>()`:

```dart
class FeatureModule extends Module {
  @override
  void binds(Binder i) {
    // Explicit parent lookup — reads from AppModule's binder
    i.registerFactory<FeatureService>(
      () => FeatureService(analytics: i.parent<AnalyticsService>()),
    );
  }
}
```

### Lookup methods

| Method | Scope searched |
|--------|---------------|
| `get<T>()` / `tryGet<T>()` | Local -> Imports -> Parent (full chain) |
| `parent<T>()` / `tryParent<T>()` | Parent scope only |

`get<T>()` already walks the full chain (local, imports, parent), so you only need `parent<T>()` when you want to **explicitly** skip local and imported registrations — for example, to avoid shadowing.

### How it works internally

`ModuleScopeState` reads the nearest ancestor `ModuleProvider` and passes its `controller.binder` as the parent when creating a new `SimpleBinder` via `BinderFactory.create(parentBinder)`. The `SimpleBinder` stores this reference and delegates to it as the last fallback in `tryGet<T>()`.

## The expects Contract

The `expects` getter declares types that **must** exist in the parent scope or imports before the module initializes. If any type is missing, initialization fails immediately with a `ModuleConfigurationException`.

```dart
class OrderModule extends Module {
  @override
  List<Type> get expects => [AuthService, ApiClient];

  @override
  List<Module> get imports => [PaymentModule()];

  @override
  void binds(Binder i) {
    // Safe to call — AuthService and ApiClient are guaranteed to exist
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

### Validation timing

`expects` is checked in `ModuleController.initialize()` **after** imports are resolved but **before** `binds()` runs. The check uses `binder.contains(type)`, which searches the full chain (imports + parent). This means expected types can come from either imported modules or a parent `ModuleScope`.

### When to use expects

- When a module relies on types provided by a parent scope (not via imports).
- To surface misconfiguration early instead of getting a `DependencyNotFoundException` at an arbitrary `get<T>()` call later.

## Configurable Modules

Modules that need runtime parameters implement the `Configurable<T>` mixin. The `configure(T args)` method is called **before** `binds()` and `onInit()`.

```dart
class UserProfileModule extends Module with Configurable<String> {
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

### Type safety

If the wrong argument type is passed, `ModuleController.configure()` catches the `TypeError` and wraps it in a `ModuleLifecycleException` with a clear message.

### configure() lifecycle position

```
configure(args) -> imports resolved -> expects validated -> binds() -> exports() -> onInit()
```

## Submodules vs Imports

Modularity distinguishes between two module relationships:

| | `imports` | `submodules` |
|--|-----------|-------------|
| **Purpose** | Runtime DI — dependency resolution | Structural — static analysis and visualization |
| **Initialization** | Resolved and initialized by `GraphResolver` | Not initialized by the framework |
| **Binder access** | Public exports are injected into the importing module's binder | No binder connection |
| **Use case** | Module A needs types from module B at runtime | Module A is logically composed of sub-features |

### imports — runtime DI

```dart
class CheckoutModule extends Module {
  @override
  List<Module> get imports => [CartModule(), PaymentModule()];

  @override
  void binds(Binder i) {
    // CartService from CartModule, PaymentService from PaymentModule
    i.registerFactory<CheckoutService>(
      () => CheckoutService(
        cart: i.get<CartService>(),
        payment: i.get<PaymentService>(),
      ),
    );
  }
}
```

### submodules — structural composition

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
    // submodules are NOT resolved here — they are for tooling only
    i.registerSingleton<AppConfig>(AppConfig());
  }
}
```

Submodules are used by `modularity_cli` tools (`ModuleBindingsAnalyzer`, `GraphVisualizer`) to build a full dependency graph for visualization and static analysis. They should use `Configurable` instead of constructor arguments so that tooling can instantiate them cleanly.

### When to use which

- Need a type from another module at runtime? Use **imports**.
- Want to document that a feature module is part of a larger module for tooling and architecture diagrams? Use **submodules**.
- A module can appear in both lists if it serves both purposes.
