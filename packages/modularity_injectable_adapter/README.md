# modularity_injectable_adapter

Utilities that connect **injectable** + **GetIt** generated wiring with the Modularity framework. Migrating an existing module requires three steps:

1. **Switch BinderFactory** – tell `ModularityRoot` to use `GetItBinderFactory`.
2. **Annotate exports** – mark public dependencies with `@moduleExportEnv` (env name `modularity_export`).
3. **Call the bridge** – invoke `ModularityInjectableBridge.configureInternal/Exports` inside your module.

```dart
import 'package:modularity_injectable_adapter/modularity_injectable_adapter.dart';

@InjectableInit(
  initializerName: 'configureInternal',
  asExtension: false,
)
void configureInternal(GetIt getIt) => configureInternal(getIt);

@InjectableInit(
  initializerName: 'configureExports',
  asExtension: false,
)
void configureExports(GetIt getIt) => configureExports(
      getIt,
      environmentFilter: const ModularityExportOnly(),
    );

class AuthModule extends Module {
  @override
  void binds(Binder i) {
    ModularityInjectableBridge.configureInternal(i, configureInternal);
  }

  @override
  void exports(Binder i) {
    ModularityInjectableBridge.configureExports(i, configureExports);
  }
}
```

In your app root:

```dart
ModularityRoot(
  binderFactory: const GetItBinderFactory(),
  child: MyApp(),
);
```

Only dependencies annotated with `@LazySingleton(env: [modularityExportEnv.name])` are exported. Everything else remains private to the module. This keeps Modularity’s explicit boundaries while letting `injectable` generate the wiring for you.*** End Patch

