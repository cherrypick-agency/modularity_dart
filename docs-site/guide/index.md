# Guide

Welcome to the **Modularity** documentation.

## Basics

- [Getting Started](./_generated/modularity_workspace/getting-started.md) — Install, create a module, wire the app
- [Module Architecture](./_generated/modularity_workspace/module-architecture.md) — Visibility, imports, parent scope, expects

## Core Concepts

- [Module Retention](./_generated/modularity_workspace/module-retention.md) — strict, routeBound, keepAlive policies
- [Hot Reload](./_generated/modularity_workspace/hot-reload.md) — How hot reload preserves module state
- [Dependency Overrides](./_generated/modularity_workspace/dependency-overrides.md) — Replace bindings for testing and feature flags

## Integrations

- [Injectable Integration](./_generated/modularity_workspace/injectable-integration.md) — Bridge to injectable/get_it
- [Routing Integration](./_generated/modularity_workspace/routing-integration.md) — GoRouter, AutoRoute, tab navigation
- [State Management](./_generated/modularity_workspace/state-management.md) — Bloc, Riverpod, MobX patterns

## Tools & Practices

- [Testing Modules](./_generated/modularity_workspace/testing-modules.md) — Unit tests, widget tests, mocking
- [CLI Tools](./_generated/modularity_workspace/cli-tools.md) — Module graph analysis and visualization
- [Best Practices](./_generated/modularity_workspace/best-practices.md) — Patterns, anti-patterns, checklists

## Packages

| Package | Description |
|---------|-------------|
| **modularity_contracts** | Core interfaces and abstractions (Binder, Module, ExportableBinder) |
| **modularity_core** | SimpleBinder, ModuleController, GraphResolver |
| **modularity_flutter** | Flutter widgets: ModuleScope, ModularityRoot, ModuleProvider |
| **modularity_cli** | CLI tools for module graph analysis and visualization |
| **modularity_injectable** | Integration bridge to injectable/get_it |
| **modularity_get_it** | Standalone GetIt adapter for Modularity |
