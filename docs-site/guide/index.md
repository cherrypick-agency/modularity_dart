# Guide

Welcome to the **Modularity** documentation.

## Packages

- **modularity_contracts** — Core interfaces and abstractions
- **modularity_core** — SimpleBinder, ModuleController, GraphResolver
- **modularity_flutter** — Flutter widgets: ModuleScope, ModularityRoot, ModuleProvider
- **modularity_cli** — CLI tools for module analysis and visualization
- **modularity_injectable** — Integration with injectable/get_it

## Topics

- [Getting Started](./modularity_workspace/getting-started.md) — Installation and first module
- [Module Architecture](./modularity_workspace/module-architecture.md) — Visibility, imports, parent scope, expects
- [Module Retention](./modularity_workspace/module-retention.md) — Retaining module state across rebuilds
- [Hot Reload](./modularity_workspace/hot-reload.md) — How hot reload works with modules
- [Dependency Overrides](./modularity_workspace/dependency-overrides.md) — Replace, extend, and intercept registrations
- [Injectable Integration](./modularity_workspace/injectable-integration.md) — Integration with injectable/get_it
- [Testing Modules](./modularity_workspace/testing-modules.md) — Unit tests, widget tests, overrides
