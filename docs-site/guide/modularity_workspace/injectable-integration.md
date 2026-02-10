# Injectable Integration

The `modularity_injectable` package replaces manual `binds()`/`exports()` wiring with [injectable](https://pub.dev/packages/injectable) code generation while preserving module boundaries.

## When to Use

| Approach | Best for |
|----------|----------|
| Manual `binds()`/`exports()` | Small modules (< 5 registrations), no build_runner needed |
| `modularity_injectable` | 10+ dependencies, constructor auto-injection, teams already using injectable/get_it |

Both approaches coexist in the same app.

## Setup

### 1. Add dependencies

```yaml
dependencies:
  modularity_core: ^0.2.0
  modularity_injectable: ^0.2.0
  get_it: ^8.0.0
  injectable: ^2.3.0

dev_dependencies:
  build_runner: ^2.4.0
  injectable_generator: ^2.4.0
```

### 2. Configure the binder factory

Injectable requires `GetItBinder` (dual-scope variant from `modularity_injectable`).

**Flutter:**

```dart
import 'package:modularity_flutter/modularity_flutter.dart';
import 'package:modularity_injectable/modularity_injectable.dart';

ModularityRoot(
  binderFactory: const GetItBinderFactory(),
  root: RootModule(),
  child: const MyApp(),
);
```

**Pure Dart:**

```dart
import 'package:modularity_injectable/modularity_injectable.dart';

final controller = ModuleController(
  RootModule(),
  binder: GetItBinder(),
  binderFactory: const GetItBinderFactory(),
);
await controller.initialize({});
```

## Annotating Dependencies

### Private (module-internal)

Standard injectable annotations. No export marker means the dependency stays private:

```dart
@LazySingleton(as: AuthRepository)
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

### Exported (visible to importing modules)

Add the `modularity_export` environment. Two equivalent syntaxes:

```dart
// Option A: env parameter
@LazySingleton(env: [modularityExportEnvName])
class AuthService {
  AuthService(this._repo);
  final AuthRepository _repo;
}

// Option B: separate annotation
@modularityExportEnv
@LazySingleton()
class AuthFacade {
  AuthFacade(this._service);
  final AuthService _service;
}
```

`modularityExportEnvName` is the string `'modularity_export'`. `modularityExportEnv` is `const Environment('modularity_export')`.

## Wiring the Module

### 1. Create the injectable config file

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

### 2. Wire into the Module

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

- `configureInternal` registers **all** annotated dependencies into the private scope.
- `configureExports` registers **only** dependencies tagged with `modularity_export` into the public scope via a `ModularityExportOnly` environment filter.

### Mixing manual and generated registrations

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    ModularityInjectableBridge.configureInternal(i, initAuthDeps);
    i.registerSingleton<AuthConfig>(AuthConfig.fromEnv());
  }

  @override
  void exports(Binder i) {
    ModularityInjectableBridge.configureExports(i, initAuthDeps);
  }
}
```

## How It Works

### Dual-scope GetItBinder

Each `GetItBinder` manages two isolated GetIt containers:

- **Private scope** (`internalContainer`) -- receives `binds()` registrations
- **Public scope** (`publicContainer`) -- receives `exports()` registrations

Dependency resolution order:

1. Local private scope
2. Local public scope
3. Imports (public exports from imported modules)
4. Parent module's binder

### BinderGetIt -- the GetIt proxy

Injectable-generated code calls `getIt.get<T>()` for constructor parameters. `BinderGetIt` wraps a GetIt instance and intercepts `get<T>()`:

1. Named/parameterized lookups delegate directly to GetIt
2. If `T` is registered locally, return it
3. Otherwise, fall back to `Binder.tryGet<T>()` (walks imports + parent)
4. If still unresolved, throw native GetIt error

This lets injectable factories depend on types from imported modules automatically:

```dart
// ApiClient is exported by NetworkModule (an import).
// Injectable resolves it through BinderGetIt -- no manual i.get() needed.
@LazySingleton()
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient);
  final ApiClient _apiClient;
}
```

### Error handling

Passing a non-GetIt binder (e.g. `SimpleBinder`) to the bridge throws `ModuleConfigurationException` immediately:

```
ModuleConfigurationException: Injectable integration requires GetItBinder.
Provide GetItBinderFactory to ModularityRoot or ModuleController.
```

::: warning
Make sure to set `GetItBinderFactory` on `ModularityRoot` or `ModuleController` before using injectable integration. The bridge validates the binder type at call time.
:::
