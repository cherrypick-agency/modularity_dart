# Comparison with Other Approaches

> **Transparency note**: This comparison is maintained by the Modularity team. We have done our best to be fair and accurate, but we are naturally biased toward our own project. If you find inaccuracies, please [open an issue](https://github.com/cherrypick-agency/modularity_dart/issues) or submit a PR.
>
> Modularity is at **v0.2.1** (core) / **v0.3.1** (flutter) as of **2026-05-19** - a young framework. Established alternatives have significant advantages in ecosystem maturity and community support.
>
> Last updated: 2026-05-19

---

## What Modularity Is (and Isn't)

Modularity is a **module lifecycle and DI boundary framework** for Flutter. It manages:
- Module initialization order (DAG-based)
- Dependency scoping (`binds` / `exports` / `expects`)
- Module lifecycle states (`initial` → `loading` → `loaded` → `error` → `disposed`)
- Retention policies (route-bound, keep-alive, strict)

Modularity is **NOT**:
- A state management solution (use BLoC, Riverpod, MobX, etc.)
- A router (use GoRouter, AutoRoute, etc.)
- A replacement for get_it or Riverpod — it can work alongside them

If you're coming from **Android**, think of it as Hilt's `@Module` + component scoping, adapted for Flutter's navigation model. If you're coming from **Angular**, it's closest to `@NgModule` with `imports`/`exports`/`providers`.

---

## When to Use Modularity

- Large apps with **10+ feature modules** that need strict dependency boundaries
- Teams where **different developers own different modules** and need contracts between them
- Apps where **module lifecycle** (creation, initialization, retention, disposal) must be explicitly managed
- Projects suffering from **"Initialization Hell"** — complex async startup sequences with ordering dependencies

## When NOT to Use Modularity

- **Small to medium apps** (< 10 features, single team) — Riverpod or get_it is likely sufficient
- **When maximum community support matters** — Riverpod and get_it have orders of magnitude more tutorials, StackOverflow answers, and production case studies
- **When you need a battle-tested, 1.0+ framework** — Modularity is pre-release with a small community
- **When minimal boilerplate is the priority** — Riverpod with codegen or injectable require less ceremony
- **When you want integrated routing** — consider flutter_modular instead
- **When building a library/package** — expose simple constructors, let consuming apps decide DI

---

## Detailed Comparisons

<a id="get-it-injectable"></a>
### get_it + injectable

The most widely used DI combination in the Flutter ecosystem.

- **What it is**: get_it is a runtime service locator with O(1) lookup. injectable is a code generator that automates get_it registration using annotations (`@singleton`, `@lazySingleton`, `@injectable`, `@module`).
- **Adoption**: Widely used in production Flutter apps, especially in teams that prefer annotation-driven wiring.
- **Pros**:
  - De facto industry standard — massive community, tutorials, and proven track record.
  - Annotation-driven registration eliminates boilerplate (`@singleton`, `@lazySingleton`).
  - Scoped containers with `pushNewScope()` / `popScope()` and automatic dispose.
  - Async initialization via `allReady()` and `isReady<T>()` with dependency flags.
  - Environment-based configuration (`@Environment('dev')`).
  - Works with **any** router and **any** state management — zero lock-in.
  - Compile-time package boundaries when combined with Melos.
- **Cons**:
  - No formal module lifecycle — scopes are managed manually via push/pop.
  - No deterministic initialization ordering — `allReady()` waits for all, but doesn't topologically sort.
  - No built-in visibility control (`binds` vs `exports`) — all registrations in a scope are accessible.
  - No graph visualization or interceptor system.
  - Requires code generation (`build_runner`) for the injectable experience.

**Where get_it + injectable is better than Modularity**: Ecosystem size, documentation, learning curve, proven track record, annotation-driven codegen, zero framework lock-in, compile-time package boundaries.

**Where Modularity adds value**: DAG-based initialization ordering, module lifecycle state machine, `expects` contract validation, `binds`/`exports` visibility control, retention policies, interceptors, Graphviz CLI visualization.

> **Note**: Modularity provides `modularity_injectable` — a bridge package that lets you keep existing injectable annotations while wrapping them in Modularity modules. This enables incremental adoption without rewriting DI registrations.

---

### Riverpod

The most popular state management framework in Flutter, with strong DI capabilities.

- **What it is**: A reactive caching and data-binding framework with compile-time-safe provider graph. Created by Remi Rousselet (also the creator of Provider).
- **Adoption**: One of the most popular Flutter state management solutions (provider graph + caching + overrides).
- **Pros**:
  - **Compile-time safety** — missing provider = compile error (with riverpod_generator).
  - **No service locator** — dependencies declared via `ref.watch()`, making the graph explicit and traceable.
  - **Explicit lifecycle** — `autoDispose`, `keepAlive`, `ref.keepAlive()`, `onDispose`, `onCancel`, `onResume`. Providers live in `ProviderContainer`, **not** the widget tree.
  - **Built-in reactivity** — consumers rebuild automatically when dependencies change.
  - **Built-in async handling** — `AsyncNotifier`, `FutureProvider`, automatic retry with exponential backoff, offline persistence (experimental in 3.0).
  - **Testing** — override any provider in one line, no mock frameworks needed for basic cases.
  - **Massive ecosystem** — extensive documentation, courses, books, conference talks.
  - **No extra widget layer** — no `ModuleScope` wrapper needed.
- **Cons**:
  - **No formal module boundaries** — any provider can be accessed from anywhere. Only Dart's `_` privacy applies.
  - **No initialization ordering guarantee** — dependencies resolve lazily/on-demand. No topological sort.
  - **Global providers can encourage coupling** across features without structural boundaries.
  - **Multi-package challenges** — `ProviderScope` can be lost across navigators in separate packages.
  - **Code generation dependency** — best experience requires `build_runner` + `riverpod_generator`.
  - **No structural observability** — no equivalent to Graphviz CLI for visualizing the full dependency graph.

**Where Riverpod is better than Modularity**: Compile-time safety, built-in reactivity, testing ergonomics, community size, async handling, no service locator pattern, lower boilerplate with codegen.

**Where Modularity adds value**: Module encapsulation (`binds`/`exports`/sealed scope), deterministic initialization ordering via DAG, multi-package module nesting, interceptors, dependency graph visualization.

> **Note**: Riverpod and Modularity solve **overlapping but distinct problems**. Riverpod excels at reactive state and data caching. Modularity provides module boundaries and lifecycle management. They can coexist — see the [State Management Integration](/guide/modularity_workspace/state-management) guide for bridge patterns.

---

### flutter_modular

The most direct competitor — an all-in-one framework combining DI, routing, and module lifecycle.

- **What it is**: A framework by Flutterando where each Module declares `binds()` for DI and `routes()` for navigation, forming a module tree.
- **Adoption**: Established community and multi-year production usage.
- **Pros**:
  - **Unified DI + routing** — reduces integration complexity.
  - **Automatic dependency resolution** via `auto_injector` (constructor-based, no code generation).
  - **Built-in route guards** with async `canActivate()` and guard chaining.
  - **Lazy module loading** — modules load on navigation, dispose on route exit.
  - **Auto-dispose** — automatic cleanup of `ChangeNotifier`, `Stream`, etc.
  - **Module imports/exports** — scoped dependency sharing between modules (since v6).
  - **Navigator 2.0** — deep linking, nested navigation via `RouterOutlet`, wildcard routes.
  - **Backend support** via `shelf_modular` for Dart servers.
  - **Mature ecosystem** — 6+ years, documentation site, migration guides between versions.
- **Cons**:
  - **Router lock-in** — cannot use GoRouter, AutoRoute, or any other router. Migration away requires rewriting both DI and routing.
  - **Breaking changes between major versions** — v3, v5, v6 each required significant rewrites.
  - **No formal module state machine** (`initial`/`loading`/`loaded`/`error`/`disposed`).
  - **No typed module configuration** — uses route arguments instead of `Configurable<T>`.
  - **No interceptor/observer system** for cross-cutting module lifecycle concerns.
  - **Docs drift** — verify behaviors against the current official documentation for your installed version.

**Where flutter_modular is better than Modularity**: Integrated routing + DI, auto-injector (no codegen, no manual registration), route guards, auto-dispose, community size, proven track record, backend support.

**Where Modularity adds value**: Router flexibility (any router via adapters), explicit lifecycle state machine, DAG-based initialization, retention policies, `Configurable<T>`, contracts/core/flutter architecture separation, interceptors, Graphviz visualization.

---

### Melos + Package-per-Feature

A build-time modularity strategy, not a runtime framework. In practice, always combined with a DI solution.

- **What it is**: Melos is a monorepo management tool. Each feature is a separate Dart package (`feature_auth`, `feature_profile`, etc.) with its own `pubspec.yaml`, tests, and CI.
- **Adoption**: Widely used monorepo tool in Dart/Flutter. Dart also provides native [pub workspaces](https://dart.dev/tools/pub/workspaces) for shared dependency resolution.
- **Pros**:
  - **Compile-time boundaries** — Dart's package system enforces visibility at the compiler level.
  - **Independent CI/CD** — each package can be tested and published independently.
  - **No framework lock-in** — standard Dart tooling, no runtime overhead.
  - **Team scalability** — proven at scale with multiple teams and hundreds of packages.
- **Cons**:
  - **No runtime lifecycle** — packages exist at build time only. No initialization ordering, no lifecycle states.
  - **"Initialization Hell"** — async startup sequences must be orchestrated manually in `main()`.
  - **No DI built-in** — always requires a separate DI solution (get_it, Riverpod, etc.).

> **Important**: The real competitor is not Melos alone, but **Melos + get_it + injectable** — the standard enterprise Flutter stack. See the [get_it + injectable](#get-it-injectable) section above for the DI comparison.

**Melos and Modularity are complementary**: Each Melos package can expose Modularity modules, giving you double boundaries — compile-time (package) + runtime (module). This mirrors Android's Gradle + Hilt pattern.

---

### Provider

A common DI pattern in Flutter apps.

- **What it is**: An `InheritedWidget` wrapper that provides objects to descendant widgets via `BuildContext`.
- **Adoption**: Long-standing and widely used across Flutter apps and tutorials.
- **Pros**:
  - Simple, well-documented, officially recommended.
  - Zero code generation, minimal learning curve.
  - Tight Flutter integration — follows the widget tree model.
- **Cons**:
  - Lifetime tied to the widget tree.
  - No compile-time safety for missing providers.
  - Cannot scope the same type twice in one widget subtree.
  - No explicit lifecycle management beyond widget mount/unmount.

---

### BLoC

An event-driven state management pattern, not a DI or modularity solution.

- **What it is**: Business Logic Component pattern using Streams for unidirectional data flow. `flutter_bloc` provides `BlocProvider` for widget-tree-based provision.
- **Adoption**: Popular pattern with a large ecosystem in Flutter.
- **Pros**:
  - Strong separation of concerns — predictable state transitions.
  - Excellent testing via `blocTest()` (unit tests, not just widget tests).
  - `BlocObserver` for global lifecycle logging.
  - Comprehensive DevTools integration.
- **Cons**:
  - Verbose boilerplate (events, states, handlers).
  - No DI mechanism — relies on `BlocProvider` (widget tree) or external DI.
  - Lifetime tied to `BlocProvider` widget.
  - Not a modularity solution — needs to be combined with get_it or similar.

> **Note**: BLoC is often combined with get_it for DI and Melos for package structure. The comparison with Modularity is primarily at the DI and lifecycle layer, not at the state management layer.

---

## Comparison Table

This table includes categories where Modularity excels **and** categories where competitors are stronger.

| Criterion | Modularity | get_it + injectable | Riverpod | flutter_modular |
| :--- | :--- | :--- | :--- | :--- |
| **Module boundaries** | `binds()` private / `exports()` public / sealed scope | Scoped containers (push/pop) | None built-in (Dart `_` only) | Module-scoped with imports/exports (v6) |
| **Initialization order** | Automatic DAG + topological sort | Manual or `allReady()` (no ordering) | Lazy/on-demand (no ordering) | Navigation-driven (implicit) |
| **Lifecycle management** | State machine + 3 retention policies | Manual scope push/pop with dispose | `autoDispose` / `keepAlive` / `onDispose` | Auto-dispose on route exit |
| **Compile-time safety** | Runtime (`expects` fail-fast) | Compile-time package boundaries | Compile-time with codegen | Runtime |
| **Observability** | Interceptors + Graphviz CLI | Limited | ProviderObserver + DevTools | Basic logging |
| **Router integration** | Any router (via adapters) | Any router (no coupling) | Any router (no coupling) | Built-in only (lock-in) |
| **Testability** | `testModule` + `TestBinder` | Override registrations, mock anything | One-line provider overrides | Module unit testing |
| **Boilerplate** | Medium-high (module class, binds, exports) | Low with codegen annotations | Low with codegen | Medium (binds + routes) |
| **Community & ecosystem** | Small (pre-release, new) | Very large | Very large | Medium |
| **Documentation** | Growing (VitePress, in development) | Extensive | Excellent (official, courses, books) | Established (migration guides) |
| **Production track record** | Limited | Extensive (industry standard) | Extensive (millions of users) | Established (6+ years) |
| **Learning curve** | High (many concepts) | Low-Medium | Medium (with codegen) | Medium |
| **Parameterization** | Typed `Configurable<T>` | Constructor args | Family providers | Route arguments |
| **Code generation** | Not required | Required (injectable) | Recommended (riverpod_generator) | Not required (auto_injector) |

---

## Decision Guide

| Team / Project Profile | Recommended Approach | Why |
| :--- | :--- | :--- |
| Solo dev, < 10 screens | get_it + manual init | Modularity's lifecycle machinery is overkill |
| Solo dev, 10-30 screens, needs structure | Riverpod | Built-in DI + state + compile-time safety |
| 2-5 devs, 20-50 screens, feature-based | **Modularity** | Module boundaries enforce team contracts. `expects` catches integration bugs early |
| 2-5 devs, already using get_it + injectable | **Modularity + modularity_injectable** | Keep existing annotations, add module lifecycle on top |
| 5-15 devs, multi-feature monorepo | **Modularity + Melos** | Double boundary: compile-time (package) + runtime (module) |
| Team migrating from Android/Hilt | **Modularity** | Closest Flutter analog to Dagger `@Module` + component scoping |
| Team migrating from iOS/TCA | Consider Riverpod first | TCA devs expect unified state + DI. Add Modularity if you need explicit lifecycle on top |

---

## Modularity's Honest Status

Modularity is at **v0.2.1** (core) / **v0.3.1** (flutter) as of **2026-05-19**. This means:

- The API may change before 1.0
- Community is small but growing
- Fewer tutorials, StackOverflow answers, and production case studies than established alternatives
- Documentation is actively being developed

We believe the architectural approach is sound — explicit module lifecycle, DAG-based initialization, and scope boundaries solve real problems in large Flutter apps. Companies like BMW (300 engineers) and Nubank (48M users) have built similar patterns custom. Modularity aims to provide this as a reusable framework.

But we acknowledge that **get_it, Riverpod, and flutter_modular have significant advantages** in ecosystem maturity, community support, and production battle-testing. Choose based on your team's needs, not on marketing claims.
