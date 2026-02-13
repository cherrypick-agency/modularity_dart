# **Architecture Design Document (RFC): Modular Framework**

Version: 1.0.3
Status: Released

Philosophy: "Glue, not Magic". Strictness in DI and Lifecycle, flexibility in UI and Routing.

## **1. Glossary and Core Abstractions**

- **Module:** Configuration class (DTO/Composition Root). Defines the dependency graph (imports), bindings (binds), and requirements (expects). **Does not hold state.**
- **ModuleController:** Module engine. Manages the lifecycle (State Machine: initial -> loading -> loaded), validates dependencies, and performs initialization.
- **Binder:** DI container abstraction. Supports scopes (parent/child).
- **ModuleScope:** Widget that connects ModuleController to the UI.
- **Retention Policy:** Memory management strategy. Uses **RouteObserver** for reliable disposal.

## **2. Module Contract**

```dart
abstract class Module {
  /// List of modules that must be initialized BEFORE this module.
  List<Module> get imports => [];

  /// List of types that the parent scope MUST provide.
  /// If a dependency is not found, initialization will fail with an error.
  List<Type> get expects => [];

  void binds(Binder i);
  void exports(Binder i) {}

  Future<void> onInit() async {}
  void onDispose() {}

  /// Hook for Hot Reload (DX).
  /// Allows updating factories without losing singleton state.
  void hotReload(Binder i) {}
}
```

## **3. Explicit Module Interface (Private vs Public)**

We apply the **Explicit Module Interface** pattern, which strictly separates internal implementations from the module's public contract. This ensures a high degree of encapsulation and prevents implementation details from leaking.

### **3.1. `binds(Binder i)` — Private Scope**
Dependencies needed **only by this module** are registered here. They are **not visible** to other modules, even if those modules import the current one.

*   **What goes here:** Repository implementations (`AuthRepositoryImpl`), data sources (`ApiService`, `LocalStorage`), mappers, internal utilities.
*   **Principle:** "Black box". The outside world should not know how the module works internally.

### **3.2. `exports(Binder i)` — Public Scope**
Dependencies that the module **provides** to the outside world are registered here. These dependencies enter the public scope and become available to modules that add this module to their `imports`.

*   **What goes here:** Service interfaces (`AuthService`), repository interfaces (if public), UseCases.
*   **Principle:** "Contract". This is the only thing other modules see.

> For debugging, you can print the current binder state:
> ```dart
> debugPrint((binder as SimpleBinder).debugGraph(includeImports: true));
> ```
> This shows which types are registered privately and which are exported.

### **Example (Google Spec Style):**

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    // --- PRIVATE: No one outside will see this ---
    // 1. Data Sources
    i.singleton<TokenStorage>(() => SecureTokenStorage());
    // 2. Implementation details
    i.singleton<AuthApi>(() => AuthApiImpl());
  }

  @override
  void exports(Binder i) {
    // --- PUBLIC: This is available to other modules ---
    // We export only the AuthService interface.
    // The AuthServiceImpl implementation is injected internally, having access to private dependencies.
    i.singleton<AuthService>(() => AuthServiceImpl(
      storage: i.get<TokenStorage>(),
      api: i.get<AuthApi>(),
    ));
  }
}
```

## **4. Dependency Injection & Scoping**

The framework supports a scope tree:
1. **Local:** Dependencies of the current module.
2. **Imports:** Public dependencies of imported modules.
3. **Parent:** Dependencies of the parent module (up the widget tree).

```dart
// Lookup: Local -> Imports -> Parent -> Error
i.get<Service>();

// Explicit request to parent
i.parent<Service>();
```

## **5. State Management Integration**

Modularity is state management agnostic. It manages the lifecycle of modules, while SM manages the UI state.

### **Bloc / Cubit**
Register Cubit in `binds` and use `BlocProvider` in the widget.

```dart
// 1. Module
class CounterModule extends Module {
  @override
  void binds(Binder i) {
    i.factory<CounterCubit>(() => CounterCubit());
  }
}

// 2. Widget
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Resolve from Module (listen: false is important for create)
      create: (context) => ModuleProvider.of(context, listen: false).get<CounterCubit>(),
      child: CounterView(),
    );
  }
}
```

### **Riverpod**
Use `ProviderScope` with `overrides` to inject dependencies from the module.

```dart
// 1. Riverpod Provider (Abstract)
final authProvider = Provider<AuthService>((ref) => throw UnimplementedError());

// 2. Widget
class RiverpodPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = ModuleProvider.of(context).get<AuthService>();

    return ProviderScope(
      overrides: [
        authProvider.overrideWithValue(authService),
      ],
      child: RiverpodView(),
    );
  }
}
```

## **6. Retention Policy & Navigation**

The lifecycle of the `ModuleScope` widget is managed by a formal `ModuleRetentionPolicy`:

- `routeBound` — default. Bound to the navigation stack (`RouteObserver`). The module is destroyed on `didPop`.
- `keepAlive` — the controller is cached in `ModuleRetainer` and can survive unmount (tabs, NestedNavigators). Released via `ModuleRetainer.evict(key)` or after app restart.
- `strict` — strict strategy. The module is destroyed on the first widget `dispose`.

```dart
ModuleScope(
  module: HomeModule(),
  retentionPolicy: ModuleRetentionPolicy.routeBound,
  retentionKey: routeName, // optional. Generated automatically by default.
  child: HomePage(),
);
```

For `routeBound`, you still need to create an observer and pass it to both `ModularityRoot` and the router:

```dart
// main.dart
final observer = RouteObserver<ModalRoute<dynamic>>();

ModularityRoot(
  observer: observer,
  child: MaterialApp(
    navigatorObservers: [observer],
    // ...
  ),
)
```

- **Push:** creates a module and subscribes to the route observer.
- **Cover (Push over):** the module stays in memory (route is still in the stack).
- **Pop:** the `routeBound` strategy calls `dispose`, the module is removed from the retainer.
- **Unmount without route events:** falls back to `strict` to prevent leaks.

### **6.1. Retention Key vs Override Scope**

**Important:** `retentionKey` and `overrideScope` are independent concepts:

| Parameter | Purpose | Affects cache? |
|-----------|---------|----------------|
| `retentionKey` | Controller identifier in the cache | Yes |
| `overrideScope` | Dependency substitution in the DI graph | No |

Two `ModuleScope` widgets with the same `retentionKey` but different `overrideScope` **share** a single controller — the first scope's overrides win.

```dart
// For override-aware caching:
ModuleScope(
  module: ConfigModule(),
  retentionKey: 'config-${identityHashCode(overrideScope)}',
  overrideScope: overrideScope,
  child: ...,
)
```

### **6.2. Lifecycle Logging**

For debugging retention behavior, pass a lifecycle logger to `ModularityRoot`:

```dart
void main() {
  runApp(ModularityRoot(
    lifecycleLogger: ModularityRoot.defaultDebugLogger,
    child: MyApp(),
  ));
}
```

Events: `created`, `reused`, `registered`, `disposed`, `evicted`, `released`, `routeTerminated`.

For analytics/monitoring integration:

```dart
ModularityRoot(
  lifecycleLogger: (event, type, {retentionKey, details}) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Module ${event.name}: $type',
      data: {'key': retentionKey?.toString(), ...?details},
    ));
  },
  child: MyApp(),
)
```

## **7. Testing Strategy**

### **Unit Testing (Headless)**
Use `testModule` from `modularity_test` for testing module logic in isolation.

```dart
await testModule(
  MyModule(),
  (module, binder) async {
    // Verify bindings
    expect(binder.get<MyService>(), isNotNull);
  }
);
```

### **Widget Testing**
For testing individual screens, use `overrides`.

```dart
ModuleScope(
  module: ProfileModule(),
  // Override dependencies BEFORE initialization
  overrides: (binder) {
    binder.singleton<Api>(() => MockApi());
  },
  child: ProfilePage(),
)
```

## **8. Routing Integration**

Modularity integrates easily with popular routing packages. The main requirement is to create an observer and pass it to both `ModularityRoot(observer: ...)` and the router.

### **GoRouter**

```dart
class AppRouter {
  static final observer = RouteObserver<ModalRoute<dynamic>>();

  static final router = GoRouter(
    observers: [observer],
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => ModuleScope(
          module: HomeModule(),
          child: HomePage(),
        ),
      ),
    ],
  );
}

// main.dart
runApp(ModularityRoot(
  observer: AppRouter.observer,
  child: MaterialApp.router(routerConfig: AppRouter.router),
));
```

### **AutoRoute**

```dart
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: HomeRoute.page, path: '/home'),
  ];
}

// main.dart
runApp(ModularityRoot(
  child: Builder(
    builder: (context) => MaterialApp.router(
      routerConfig: appRouter.config(
        navigatorObservers: () => [ModularityRoot.observerOf(context)],
      ),
    ),
  ),
));

// HomePage (Inside ModuleScope)
@RoutePage()
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: HomeModule(),
      child: Scaffold(...),
    );
  }
}
```

## **9. Developer Tools (CLI)**

Use `modularity_cli` to visualize the dependency graph.

```bash
# Create a script in tool/visualize.dart
dart tool/visualize.dart
```

This will generate an HTML file with an interactive module graph.
