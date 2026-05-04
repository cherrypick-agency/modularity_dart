## 0.2.1

- `GraphResolver` and `ModuleRegistryKey` now include `Module.identityKey` in
  imported controller identity, preventing accidental reuse between same-type
  modules with different runtime constructor state.
- Circular dependency detection now uses module type plus `Module.identityKey`,
  allowing valid same-type import chains with different runtime identity while
  still rejecting true cycles.
- `ModuleController.dispose` now awaits async module cleanup and remains
  idempotent across repeated dispose calls.
- `ModuleController.dispose` no longer calls `Module.onDispose` for controllers
  whose initialization lifecycle never started.
- Imported module controllers are retained by dependent count and disposed only
  after the last dependent releases them.
- `GraphResolver` recreates disposed imported controllers instead of returning a
  stale disposed controller from the registry.
- `ModuleController.initialize` now coalesces concurrent calls and rejects
  reinitialization after `error` or `disposed` states.
- `ModuleController.dispose` now waits for in-flight initialization before
  running cleanup, preventing `loading -> loaded` races after disposal.
- Binding/export mode is reset with `try/finally` so failed exports and hot
  reloads cannot leave the binder in export mode.
- Interceptor and cleanup failures during initialization are now contained so
  controllers reach `error` state and preserve the original initialization
  failure.
- Configuration failures now move the controller to `error` and configuration
  is rejected after initialization starts.

## 0.2.0

- `SimpleBinder`, `ModuleController`, and `GraphResolver` now throw typed exceptions
  (`DependencyNotFoundException`, `CircularDependencyException`, `ModuleConfigurationException`,
  `ModuleLifecycleException`) instead of generic errors.
- Added comprehensive dartdoc coverage on all public APIs.
- Added strict `analysis_options.yaml` (strict-casts, strict-inference, strict-raw-types).

## 0.1.0

- Added `ModuleOverrideScope` for hierarchical overrides and exported it via
  `modularity_core`.
- Added `ModuleRegistryKey` for override-aware controller caching. Controllers
  with different override scopes are now stored separately in the global registry.
- `ModuleController.hotReload` now preserves singleton instances while
  refreshing factories and re-applies overrides automatically (uses the new
  `RegistrationStrategy.preserveExisting`).
- `SimpleBinder` implements `RegistrationAwareBinder` and respects preserve mode
  for both private and public scopes.
- `GraphResolver` and `ModuleController` now pass override scopes down to child
  modules.

## 0.0.2

- Implemented `sealPublicScope()` and `resetPublicScope()` in `SimpleBinder`
- Added `isExportModeEnabled` and `isPublicScopeSealed` getters
- Improved README with detailed documentation and examples
- Improved package metadata for pub.dev (topics, issue_tracker)

## 0.0.1

- Initial release.
