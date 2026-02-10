# Hot Reload Guide for Modularity

## Why extended hot reload matters

Previously, re-running `binds()` would wipe already-created singletons and often throw duplicate-export errors. With the new implementation, hot reload:

- preserves all created singleton and `registerSingleton` instances;
- updates only factories (`registerFactory`, `registerLazySingleton`);
- re-applies `ModuleOverrideScope` and the user-defined `module.hotReload` hook.

This approach **eliminates the need to recreate controllers** and makes code updates predictable even for complex module graphs.

## RegistrationStrategy and RegistrationAwareBinder

`modularity_contracts` introduces the `RegistrationStrategy` enum and the `RegistrationAwareBinder` interface. Strategies are used exclusively during hot reload and test overrides:

| Strategy | Behaviour |
|----------|-----------|
| `replace` | re-registration overwrites the existing entry (legacy behaviour) |
| `preserveExisting` | singletons are kept; only the factory delegate is updated |

`SimpleBinder` and `GetItBinder` already implement this contract, so end-users simply call `controller.hotReload()`. If you build a custom binder, implement the interface and respect the current strategy in your `register*` methods.

Example implementation fragment:

```dart
class MyBinder implements RegistrationAwareBinder {
  final _stack = <RegistrationStrategy>[RegistrationStrategy.replace];

  @override
  RegistrationStrategy get registrationStrategy => _stack.last;

  @override
  T runWithStrategy<T>(RegistrationStrategy strategy, T Function() body) {
    _stack.add(strategy);
    try {
      return body();
    } finally {
      _stack.removeLast();
    }
  }

  @override
  void registerLazySingleton<T extends Object>(T Function() factory) {
    if (registrationStrategy == RegistrationStrategy.preserveExisting &&
        _hasSingleton<T>()) {
      _updateFactory(factory);
      return;
    }
    _storeSingleton(factory);
  }
}
```

`ModuleController` automatically wraps rebinds in `runWithStrategy(RegistrationStrategy.preserveExisting, ...)` during hot reload, so you never need to switch strategy manually in normal usage.

## ModuleOverrideScope and re-applying overrides

`ModuleOverrideScope` describes an override tree: the current module (`selfOverrides`) plus a `children` map for imported modules. Example:

```dart
final overrides = ModuleOverrideScope(children: {
  AuthModule: ModuleOverrideScope(
    selfOverrides: (binder) =>
        binder.singleton<AuthApi>(() => FakeAuthApi()),
  ),
});
```

- In Flutter: `ModuleScope(overrideScope: overrides, ...)`.
- In tests: `testModule(MyModule(), body, overrideScope: overrides);`

Overrides run after `binds` but before `exports`, and are automatically re-applied on `hotReload()` without extra code.

## Hot reload step by step

1. `ModuleController.hotReload()` checks the module is in `loaded` status.
2. For exportable binders, `resetPublicScope()` is called so that public dependencies can be re-registered.
3. The binder switches to the `preserveExisting` strategy.
4. The following methods are executed in order:
   - `module.binds(binder);`
   - `_applyOverridesIfNeeded();` (current scope node)
   - `module.exports(binder);`
   - `sealPublicScope();`
5. Finally, `module.hotReload(binder);` — the user hook — is invoked.

## Testing

- `dart test` in `packages/core` verifies singleton preservation and factory refresh (`HotReloadModule` tests).
- `packages/adapters/modularity_get_it` contains tests confirming the GetIt adapter behaviour.
- In a running app, you can call `controller.hotReload()` directly, or rely on Flutter hot reload — Modularity automatically triggers `ModuleScope` rebuilds when code changes.

## FAQ

**Do I need to manually reset singletons?**  
No. If you want to restart a module from scratch, call `controller.dispose()` and create a new `ModuleController`.

**Why does re-registering a public binding still throw an error?**  
The public scope is protected by `sealPublicScope`. Before hot reload, `resetPublicScope()` is called, so there is no error inside `ModuleController.hotReload()`. If you try to manually re-export outside of that context, the guard remains intentional.

**Can I apply `RegistrationStrategy.preserveExisting` to a subset of code?**  
Yes. Any `RegistrationAwareBinder` exposes `runWithStrategy`. For example, to update several factories without losing state:

```dart
final binder = ModuleProvider.of(context) as RegistrationAwareBinder;
binder.runWithStrategy(
  RegistrationStrategy.preserveExisting,
  () {
    binder.registerFactory<Foo>(() => Foo());
    binder.registerLazySingleton<Bar>(() => Bar());
  },
);
```

Use this with care and only when you explicitly need rebind behaviour that preserves existing instances.
