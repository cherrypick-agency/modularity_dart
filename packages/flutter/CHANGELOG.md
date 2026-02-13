## 0.3.0

### Breaking Changes

- **Removed `Modularity` static singleton class.** All state moved into `ModularityRoot` widget.
  - `Modularity.observer` → `ModularityRoot(observer: ...)` + `ModularityRoot.observerOf(context)`
  - `Modularity.interceptors` → `ModularityRoot(interceptors: [...])`+ `ModularityRoot.interceptorsOf(context)`
  - `Modularity.enableDebugLogging()` → `ModularityRoot(lifecycleLogger: ModularityRoot.defaultDebugLogger)`
  - `Modularity.lifecycleLogger` → `ModularityRoot(lifecycleLogger: ...)`
  - `Modularity.log(...)` → `ModularityRoot.log(context, ...)`
  - `Modularity.disableLogging()` → omit `lifecycleLogger` (null by default)

- **`ModularityRoot` is now a `StatefulWidget`** (was `InheritedWidget`).
  - Immutable fields (`binderFactory`, `observer`, `retainer`, `interceptors`) are locked in `initState` and cannot change.
  - `lifecycleLogger` can change (hot reload, toggle) without error.
  - `didUpdateWidget` reports errors via `FlutterError.reportError` for immutable field changes.

- **`ModuleRetentionBinding.observer` is now a required field** (was a getter reading `Modularity.observer`).

- **`ModuleRetainer` has a `logger` field** for lifecycle logging (set by `ModularityRoot`).

### New Features

- `ModularityRoot.defaultDebugLogger` -- static const logger for debug output.
- `ModularityRoot.observerOf(context)` -- typed accessor for the observer.
- `ModularityRoot.interceptorsOf(context)` -- typed accessor for interceptors.
- `ModularityRoot.log(context, event, type, ...)` -- log helper via inherited widget.
- Debug warning when `observer` is not provided (route-bound retention won't work).

### Tests

- Added unit tests for `ModularityRoot` widget: `didUpdateWidget` immutable field protection,
  `lifecycleLogger` hot-swap, `dispose` cleanup, and `initState` defaults.

### Internal

- Extracted `_build*` methods from `ModuleScope` into separate widgets.
- Resolved 11 bugs found by production readiness audit.

## 0.2.0

- Widgets and retention logic now throw typed exceptions from `modularity_contracts`
  instead of generic errors.
- Added comprehensive dartdoc coverage on all public APIs.
- Added strict `analysis_options.yaml` (strict-casts, strict-inference, strict-raw-types).

## 0.1.0

### Retention Policies
- `ModuleScope` gained `retentionPolicy`/`retentionKey`/`retentionExtras`
  support plus the new `overrideScope` parameter for child override trees.
- Formal `ModuleRetentionPolicy` enum: `strict`, `routeBound`, `keepAlive`.
- Pluggable retention strategies with route-aware lifecycle management.
- `KeepAlive` modules now correctly dispose when owning route terminates.

### Lifecycle Logging
- Added `ModuleLifecycleEvent` enum and `ModuleLifecycleLogger` callback.
- New `Modularity.enableDebugLogging()` for console output in debug builds.
- Events: `created`, `reused`, `registered`, `disposed`, `evicted`, `released`,
  `routeTerminated`.

### Documentation
- Documented `retentionKey` vs `overrideScope` contract in `ModuleScope` and
  `ModuleRetainer` doc comments.
- Updated README with lifecycle logging and retention contract examples.

## 0.0.2

- Updated dependencies to modularity_contracts ^0.0.2 and modularity_core ^0.0.2
- Improved package metadata for pub.dev (topics, issue_tracker)

## 0.0.1

- Initial release.
