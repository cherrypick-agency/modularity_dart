# modularity_injectable_adapter

[![pub package](https://img.shields.io/pub/v/modularity_injectable_adapter.svg)](https://pub.dev/packages/modularity_injectable_adapter)

Optional integration package that connects **injectable** + **GetIt** code generation with the Modularity framework.

> **Note:** This package is entirely optional. The core Modularity framework works perfectly with manual `binds`/`exports` registration. Use this adapter only if you prefer auto-wiring via `injectable`.

## Features

- `GetItBinder` — a `Binder` implementation backed by scoped GetIt instances
- `ModularityInjectableBridge` — helper to invoke injectable-generated functions inside `binds`/`exports`
- `modularityExportEnv` — environment constant to mark dependencies for export

## Installation

```yaml
dependencies:
  modularity_injectable_adapter: ^0.0.1

dev_dependencies:
  build_runner: ^2.4.0
  injectable_generator: ^2.4.0
```

## Quick Start

### 1. Configure your app root

```dart
ModularityRoot(
  binderFactory: const GetItBinderFactory(),
  child: MyApp(),
);
```

### 2. Create injectable configuration

```dart
// lib/di/auth_injectable.dart
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

@InjectableInit(initializerName: 'configureAuthInternal', asExtension: false)
void configureAuthInternal(GetIt getIt) => $initGetIt(getIt);

@InjectableInit(initializerName: 'configureAuthExports', asExtension: false)
void configureAuthExports(GetIt getIt, {EnvironmentFilter? environmentFilter}) =>
    $initGetIt(getIt, environmentFilter: environmentFilter);
```

### 3. Annotate your dependencies

```dart
@LazySingleton()
class AuthRepositoryImpl implements AuthRepository { ... }

// Mark for export with modularityExportEnv
@LazySingleton(env: [modularityExportEnvName])
class AuthService { ... }
```

### 4. Wire up your module

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    ModularityInjectableBridge.configureInternal(i, configureAuthInternal);
  }

  @override
  void exports(Binder i) {
    ModularityInjectableBridge.configureExports(i, configureAuthExports);
  }
}
```

## How It Works

- `configureInternal` registers **all** dependencies into the private scope
- `configureExports` registers **only** dependencies annotated with `@modularityExportEnv` into the public scope
- This preserves Modularity's strict module boundaries while letting `injectable` generate the wiring

## Manual Alternative

If you prefer explicit registration without code generation, simply use the standard approach:

```dart
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    i.singleton<AuthRepository>(() => AuthRepositoryImpl());
  }

  @override
  void exports(Binder i) {
    i.singleton<AuthService>(() => AuthService(i.get()));
  }
}
```

See the [main Modularity documentation](https://github.com/cherrypick-agency/modularity_dart) for more details.

