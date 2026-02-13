# Best Practices

Practical guidelines for designing modules, managing dependencies, and avoiding common pitfalls.

## Module Granularity

One domain = one module. A module should encapsulate a single feature or bounded context.

**Good:**

```dart
class AuthModule extends Module { ... }
class PaymentModule extends Module { ... }
class ProfileModule extends Module { ... }
```

**Bad:**

```dart
// God module -- too many responsibilities
class AppModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<AuthService>(() => AuthService());
    i.registerLazySingleton<PaymentService>(() => PaymentService());
    i.registerLazySingleton<ProfileService>(() => ProfileService());
    i.registerLazySingleton<NotificationService>(() => NotificationService());
    // ...20 more registrations
  }
}
```

Split large modules when:
- The module has more than 10 registrations.
- Registrations span multiple unrelated domains.
- Different parts of the module have different lifecycles (some route-scoped, some app-scoped).

## imports vs Parent Scope

Two mechanisms for accessing external dependencies:

| Mechanism | How | When to use |
|-----------|-----|-------------|
| `imports` | Module lists imported modules in `get imports` | Sibling modules that export shared services |
| Parent scope | Dependency registered in an ancestor `ModuleScope` | Parent-child widget tree relationships |

**Use `imports` when:**
- The dependency comes from a logically separate module (e.g. `AuthModule` exports `AuthService` that `PaymentModule` imports).
- You want explicit, visible dependency declarations.
- Modules are reusable across different parts of the app.

**Use parent scope when:**
- The dependency is naturally hierarchical (root services available to all children).
- You use `ModuleScope` nesting in the widget tree.
- The dependency lifecycle is tied to the parent route.

```dart
// imports: explicit module dependency
class PaymentModule extends Module {
  @override
  List<Module> get imports => [AuthModule()];

  @override
  void binds(Binder i) {
    i.registerLazySingleton<PaymentService>(
      () => PaymentService(i.get<AuthService>()),
    );
  }
}

// Parent scope: hierarchical, declared via expects
class SettingsModule extends Module {
  @override
  List<Type> get expects => [AuthService];

  @override
  void binds(Binder i) {}
}
```

## binds() vs exports()

| Method | Scope | Visibility | Use for |
|--------|-------|------------|---------|
| `binds()` | Private | Only within the module | Repositories, data sources, use cases, internal services |
| `exports()` | Public | Importing modules and children | Facades, public APIs, shared contracts |

**Decision criteria:**

- If only this module needs it -> `binds()`.
- If other modules need it -> `exports()`.
- If in doubt, start with `binds()`. Promote to `exports()` when another module actually needs it.

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    // Private: implementation details
    i.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(),
    );
    i.registerLazySingleton<TokenStorage>(
      () => SecureTokenStorage(),
    );
  }

  @override
  void exports(Binder i) {
    // Public: only the facade
    i.registerLazySingleton<AuthService>(
      () => AuthService(
        i.get<AuthRepository>(),
        i.get<TokenStorage>(),
      ),
    );
  }
}
```

Modules that import `AuthModule` can resolve `AuthService` but cannot access `AuthRepository` or `TokenStorage`.

## Error Handling

### expects for fail-fast validation

Declare expected parent dependencies to catch configuration errors at initialization time, not at first use:

```dart
class CheckoutModule extends Module {
  @override
  List<Type> get expects => [AuthService, CartService];

  @override
  void binds(Binder i) {
    // AuthService and CartService are guaranteed to exist
    i.registerFactory<CheckoutCubit>(
      () => CheckoutCubit(
        auth: i.get<AuthService>(),
        cart: i.get<CartService>(),
      ),
    );
  }
}
```

Without `expects`, missing dependencies surface as `DependencyNotFoundException` at an unpredictable time.

### Error handling in onInit

Use `onInit()` for async initialization that can fail. Errors are caught by `ModuleController` and exposed via the `errorBuilder` in `ModuleScope`:

```dart
class DatabaseModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<Database>(() => Database());
  }

  @override
  Future<void> onInit() async {
    final db = binder.get<Database>(); // won't work -- no binder access here
  }
}
```

Note: `onInit()` does not receive the binder. If you need to access registered dependencies during async init, resolve them via a registered service:

```dart
class DatabaseModule extends Module {
  late final DatabaseInitializer _initializer;

  @override
  void binds(Binder i) {
    _initializer = DatabaseInitializer();
    i.registerSingleton<DatabaseInitializer>(_initializer);
    i.registerLazySingleton<Database>(
      () => _initializer.database,
    );
  }

  @override
  Future<void> onInit() async {
    await _initializer.connect();
  }
}
```

### Exception types

Modularity throws typed exceptions for different failure modes:

| Exception | When |
|-----------|------|
| `DependencyNotFoundException` | `get<T>()` cannot find the type in any scope |
| `CircularDependencyException` | Module import graph has a cycle |
| `ModuleConfigurationException` | Sealed scope violation, duplicate export, wrong binder type |
| `ModuleLifecycleException` | Configure type mismatch, dependent module failure |

All extend `ModularityException`. Catch `ModularityException` to handle any framework error.

## Performance

### Lazy singletons vs eager singletons

| Registration | Created when | Use for |
|-------------|-------------|---------|
| `registerLazySingleton` | First `get<T>()` call | Most services -- defers cost until needed |
| `registerSingleton` | Immediately at `binds()` time | Pre-built instances, config objects |
| `registerFactory` | Every `get<T>()` call | Stateless use cases, transient objects |

Prefer `registerLazySingleton` for most services. Use `registerSingleton` only when you already have the instance (e.g. config parsed at startup). Use `registerFactory` for objects that should not be shared.

### Module initialization cost

`onInit()` runs after `binds()` and `exports()`. Heavy async work here blocks the module from reaching `loaded` status. The `ModuleScope` shows the `loadingBuilder` during this time.

To minimize perceived latency:
- Keep `onInit()` light. Move heavy work to lazy initialization inside services.
- Use `loadingBuilder` to show meaningful skeleton UI instead of a spinner.
- For modules with no async setup, omit `onInit()` entirely (the default is a no-op).

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Module class | `<Feature>Module` | `AuthModule`, `PaymentModule` |
| Root module | `RootModule` or `AppModule` | `RootModule` |
| Exported service | `<Feature>Service` or `<Feature>Facade` | `AuthService` |
| Private repository | `<Feature>Repository` / `<Feature>RepositoryImpl` | `AuthRepositoryImpl` |
| Config module | `<Feature>Module implements Configurable<T>` | `DetailsModule implements Configurable<String>` |

## Anti-Patterns

### God modules

A module that registers everything for the entire app. This defeats the purpose of modularization.

**Fix:** Split into domain-specific modules. Use `imports` to connect them.

### Circular dependencies

Module A imports Module B, which imports Module A.

```dart
// This will throw CircularDependencyException
class ModuleA extends Module {
  @override
  List<Module> get imports => [ModuleB()];
  // ...
}

class ModuleB extends Module {
  @override
  List<Module> get imports => [ModuleA()];
  // ...
}
```

**Fix:** Extract the shared dependency into a third module that both A and B import. Or move the shared type to a parent scope.

### Leaking internals

Exporting implementation classes instead of interfaces:

```dart
// Bad: exports the implementation
void exports(Binder i) {
  i.registerLazySingleton<AuthRepositoryImpl>(
    () => AuthRepositoryImpl(),
  );
}

// Good: exports the interface
void exports(Binder i) {
  i.registerLazySingleton<AuthService>(
    () => AuthServiceImpl(i.get<AuthRepository>()),
  );
}
```

**Fix:** Export abstract types or facades. Keep implementations private.

### Resolving during binds()

Calling `i.get<T>()` in `binds()` to resolve a dependency that is registered later in the same method:

```dart
void binds(Binder i) {
  // Bad: UserService is not registered yet
  i.registerLazySingleton<UserCubit>(
    () => UserCubit(i.get<UserService>()),
  );
  i.registerLazySingleton<UserService>(() => UserService());
}
```

This works at runtime because `registerLazySingleton` defers creation. But it fails with `RecordingBinder` during static analysis. **Fix:** Order registrations so dependencies are registered before dependents, or rely on the fact that lazy resolution defers the `get` call.

### Ignoring expects

Resolving parent dependencies without declaring them in `expects`:

```dart
class PaymentModule extends Module {
  @override
  void binds(Binder i) {
    i.registerFactory<PaymentCubit>(
      () => PaymentCubit(i.get<AuthService>()), // silent parent lookup
    );
  }
}
```

This works but fails silently if the parent doesn't provide `AuthService`. **Fix:** Declare `expects` for any type resolved from a parent scope:

```dart
class PaymentModule extends Module {
  @override
  List<Type> get expects => [AuthService];

  @override
  void binds(Binder i) {
    i.registerFactory<PaymentCubit>(
      () => PaymentCubit(i.get<AuthService>()),
    );
  }
}
```

## Checklist for Creating a New Module

1. **Define the module class** extending `Module`.
2. **Decide scope:** What is private (`binds`) vs public (`exports`)?
3. **Declare `expects`** for any dependency from parent or imported scopes.
4. **Declare `imports`** for any sibling modules this module depends on.
5. **Register dependencies** using `registerLazySingleton` (shared) or `registerFactory` (transient).
6. **Add `onInit()`** only if async initialization is needed.
7. **Add `onDispose()`** only if non-DI cleanup is needed (timers, sockets).
8. **Implement `Configurable<T>`** if the module needs runtime parameters.
9. **Wrap in `ModuleScope`** at the route or widget level.
10. **Test in isolation** using `ModuleController` with a `SimpleBinder`.

```dart
class FeatureModule extends Module implements Configurable<String> {
  late String _featureId;

  @override
  void configure(String args) => _featureId = args;

  @override
  List<Module> get imports => [SharedModule()];

  @override
  List<Type> get expects => [AuthService];

  @override
  void binds(Binder i) {
    i.registerLazySingleton<FeatureRepository>(
      () => FeatureRepositoryImpl(
        id: _featureId,
        api: i.get<ApiClient>(),
      ),
    );
    i.registerFactory<FeatureCubit>(
      () => FeatureCubit(i.get<FeatureRepository>()),
    );
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<FeatureService>(
      () => FeatureService(i.get<FeatureRepository>()),
    );
  }

  @override
  Future<void> onInit() async {
    // Optional async setup
  }

  @override
  void onDispose() {
    // Optional cleanup
  }
}
```
