# Injectable Integration Guide

Modularity modules use `binds()` and `exports()` to register dependencies manually. The `modularity_injectable` package replaces that manual wiring with [injectable](https://pub.dev/packages/injectable) code generation while preserving strict module boundaries.

## When to Use This

**Manual registration** (default approach):

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
    i.registerFactory<LoginUseCase>(() => LoginUseCase(i.get()));
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<AuthService>(() => AuthService(i.get()));
  }
}
```

This works well for small modules with a handful of dependencies. You see every registration, and there is no code generation step.

**Injectable auto-wiring** (`modularity_injectable`):

```dart
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository { ... }

@Injectable()
class LoginUseCase {
  LoginUseCase(this._repo);
  final AuthRepository _repo;
}

@LazySingleton(env: [modularityExportEnvName])
class AuthService {
  AuthService(this._repo);
  final AuthRepository _repo;
}
```

Use this when:

- A module has 10+ dependencies and manual wiring becomes tedious.
- You want constructor injection resolved automatically.
- Your team already uses `injectable` / `get_it` in other projects.

Avoid this when:

- The module is small (< 5 registrations). Manual wiring is simpler.
- You do not want a `build_runner` step in your workflow.

Both approaches can coexist in the same app. Some modules can use manual registration while others use injectable.

## Setup

### 1. Add dependencies

```yaml
# pubspec.yaml
dependencies:
  modularity_core: ^0.2.0
  modularity_injectable: ^0.2.0
  get_it: ^8.0.0
  injectable: ^2.3.0

dev_dependencies:
  build_runner: ^2.4.0
  injectable_generator: ^2.4.0
```

### 2. Switch the binder factory

Modularity needs `GetItBinder` (the dual-scope variant from `modularity_injectable`) to work with injectable. Tell the root widget to produce them:

**Flutter app:**

```dart
import 'package:modularity_flutter/modularity_flutter.dart';
import 'package:modularity_injectable/modularity_injectable.dart';

ModularityRoot(
  binderFactory: const GetItBinderFactory(),
  root: RootModule(),
  child: const MyApp(),
);
```

**Pure Dart (no Flutter):**

```dart
import 'package:modularity_injectable/modularity_injectable.dart';

final controller = ModuleController(
  RootModule(),
  binder: GetItBinder(),
  binderFactory: const GetItBinderFactory(),
);
await controller.initialize({});
```

`GetItBinderFactory` is the `BinderFactory` that creates `GetItBinder` instances. Each `GetItBinder` manages two isolated GetIt containers — one for private dependencies and one for public exports.

## Annotating Dependencies

### Private dependencies (internal to the module)

Use standard `injectable` annotations. Dependencies without the export environment marker stay private to the module:

```dart
@LazySingleton()
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient);
  final ApiClient _apiClient;
}

@Injectable()
class LoginUseCase {
  LoginUseCase(this._repo);
  final AuthRepository _repo;
}
```

### Exported dependencies (visible to importing modules)

Mark them with the `modularity_export` environment so that `ModularityExportOnly` can filter them during the `exports()` phase. Two equivalent syntaxes:

**Option A — `env` parameter on the registration annotation:**

```dart
@LazySingleton(env: [modularityExportEnvName])
class AuthService {
  AuthService(this._repo);
  final AuthRepository _repo;
}
```

**Option B — `@modularityExportEnv` as a separate annotation:**

```dart
@modularityExportEnv
@LazySingleton()
class AuthFacade {
  AuthFacade(this._service);
  final AuthService _service;
}
```

Both produce the same result. The constant `modularityExportEnvName` equals `'modularity_export'`, and `modularityExportEnv` is `const Environment('modularity_export')`.

### Registering against an interface

Use the `as` parameter to register an implementation under its abstract type:

```dart
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository { ... }
```

### Named registrations

`@Named` works as usual. Named registrations resolve through GetIt directly (Modularity's Binder does not participate in named lookups):

```dart
@Named('baseUrl')
@Injectable()
class ApiBaseUrl {
  final String value = 'https://api.example.com';
}
```

## Wiring the Module

### 1. Create the injectable config file

Each module gets its own `@InjectableInit` file. The generator will create a `$initGetIt` function in the corresponding `.config.dart` file.

```dart
// lib/modules/auth/auth_injectable.dart
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'auth_injectable.config.dart';

@InjectableInit(initializerName: 'initAuthDeps', asExtension: false)
GetIt initAuthDeps(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    $initGetIt(
      getIt,
      environment: environment,
      environmentFilter: environmentFilter,
    );
```

Run code generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 2. Wire into the Module class

```dart
import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';

import 'auth_injectable.dart';

class AuthModule extends Module {
  @override
  void binds(Binder i) {
    ModularityInjectableBridge.configureInternal(i, initAuthDeps);
  }

  @override
  void exports(Binder i) {
    ModularityInjectableBridge.configureExports(i, initAuthDeps);
  }

  @override
  List<Type> get expects => [ApiClient];
}
```

`configureInternal` registers **all** annotated dependencies into the private scope.
`configureExports` registers **only** dependencies tagged with `env: [modularityExportEnvName]` (or `@modularityExportEnv`) into the public scope.

Both calls receive the same generated function. The difference is that `configureExports` passes a `ModularityExportOnly` environment filter that rejects anything without the export marker.

### Mixing manual and generated registrations

You can combine both approaches in a single module:

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    // Auto-wired dependencies
    ModularityInjectableBridge.configureInternal(i, initAuthDeps);

    // Manual registration for things that don't fit injectable
    i.registerSingleton<AuthConfig>(AuthConfig.fromEnv());
  }

  @override
  void exports(Binder i) {
    ModularityInjectableBridge.configureExports(i, initAuthDeps);
  }
}
```

## How It Works Under the Hood

### Dual-scope GetItBinder

Each `GetItBinder` (from `modularity_injectable`) creates two isolated GetIt containers:

```
GetItBinder
├── _privateScope: GetIt.asNewInstance()   // binds() registrations
├── _publicScope:  GetIt.asNewInstance()   // exports() registrations
├── _imports: List<Binder>                // imported module binders
└── _parent: Binder?                      // parent scope binder
```

When `isExportMode` is `false` (during `binds()`), all registrations go to `_privateScope`. When `isExportMode` is `true` (during `exports()`), they go to `_publicScope`.

Dependency resolution follows a strict priority:

1. **Local private scope** (`_privateScope`)
2. **Local public scope** (`_publicScope`)
3. **Imports** — only public exports from imported modules (`tryGetPublic`)
4. **Parent** — the parent module's binder

This is the same resolution chain that manual Modularity uses, ensuring consistent behavior.

### BinderGetIt — the GetIt proxy

Injectable-generated code calls `getIt.get<T>()` to resolve constructor parameters. A raw GetIt instance cannot see dependencies from imported modules or the parent scope. `BinderGetIt` bridges this gap.

`BinderGetIt` implements the `GetIt` interface but intercepts `get<T>()` calls:

```
getIt.get<T>()
  │
  ├── Has instanceName / param1 / param2?
  │   └── Yes → delegate directly to the underlying GetIt (injectable-specific features)
  │
  ├── Is T registered in the primary GetIt container?
  │   └── Yes → return it
  │
  ├── Can Binder.tryGet<T>() resolve it?
  │   └── Yes → return it (this walks imports + parent)
  │
  └── Fall through to primary GetIt → throws native GetIt error
```

This means injectable factories can depend on types registered in imported modules or the parent scope without any manual `i.get()` calls:

```dart
// ApiClient is exported by NetworkModule (an import)
// injectable resolves it automatically through BinderGetIt

@LazySingleton()
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient); // resolved via imports
  final ApiClient _apiClient;
}
```

### ModularityExportOnly — the environment filter

`ModularityExportOnly` extends injectable's `EnvironmentFilter`. It accepts registrations only when their environment set contains `'modularity_export'`:

```dart
class ModularityExportOnly extends EnvironmentFilter {
  const ModularityExportOnly() : super(const {'modularity_export'});

  @override
  bool canRegister(Set<String> depEnvironments) {
    if (depEnvironments.isEmpty) return false;
    return depEnvironments.contains(modularityExportEnvName);
  }
}
```

When `ModularityInjectableBridge.configureExports` calls the generated init function, it passes this filter. The generated code checks `environmentFilter.canRegister(...)` for each registration and skips anything that does not carry the export marker.

### The complete flow

```
Module.binds(binder) called by ModuleController
  │
  └── ModularityInjectableBridge.configureInternal(binder, initFn)
        │
        ├── Wraps binder.internalContainer in BinderGetIt
        └── Calls initFn(binderGetIt)
              └── Generated code registers ALL deps into private GetIt
                  (BinderGetIt falls back to Binder for cross-module deps)

Module.exports(binder) called by ModuleController
  │
  └── ModularityInjectableBridge.configureExports(binder, initFn)
        │
        ├── Wraps binder.publicContainer in BinderGetIt
        └── Calls initFn(binderGetIt, environmentFilter: ModularityExportOnly())
              └── Generated code registers ONLY @modularityExportEnv deps
                  into the public GetIt scope
```

After both phases complete, the public scope is sealed. Importing modules see only the public exports, and private implementation details remain hidden.

### Error handling

If you pass a non-GetIt binder (e.g. the default `SimpleBinder`) to the bridge, it throws `ModuleConfigurationException` immediately:

```
ModuleConfigurationException: Injectable integration requires GetItBinder.
Provide GetItBinderFactory to ModularityRoot or ModuleController.
```

This fail-fast behavior prevents confusing runtime errors from mismatched binder types.
