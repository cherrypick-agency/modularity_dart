# Complex MobX Example

A "Real World" E-Commerce application demonstrating the full power of the Modularity Framework with MobX.

## Features

- **Nested Modules**: 
  - `RootModule` (Global State)
  - `MainModule` (Dashboard/Tabs)
  - `HomeModule`, `CartModule`, `SettingsModule` (Tab Contents)
  - `AuthModule` (Login Flow)
- **Global State Management**: `CartStore` and `AuthStore` are singletons living in `RootModule`, accessible by all child modules via dependency injection (`Binder` parent lookup).
- **Tab Navigation**: Demonstrates how to use `ModuleScope` inside `IndexedStack` to keep module state alive while switching tabs.
- **MobX Integration**: Uses `Observer` widgets and `Store` classes for reactive UI updates.
- **E2E Testing**: Comprehensive tests covering the entire user flow (Login -> Shop -> Cart -> Settings -> Logout).

## Architecture

```
RootModule (AuthStore, CartStore)
  ├── AuthModule (Login)
  └── MainModule (Dashboard)
        ├── HomeModule (Product List)
        ├── CartModule (Cart View)
        └── SettingsModule (Profile)
```

## Running

1. Generate MobX code:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
2. Run the app:
   ```bash
   flutter run
   ```
3. Run tests:
   ```bash
   flutter test
   ```

