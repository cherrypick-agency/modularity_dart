# Modularity + Riverpod Example

This example demonstrates how to use **Modularity** alongside **Riverpod**.

## Why use Modularity if I have Riverpod?

It is not an "either/or" choice. **Riverpod** is primarily a **State Management** library (with DI capabilities), while **Modularity** is an **Architecture Framework** focused on module management, isolation, and lifecycle.

Here is why using them together creates a robust architecture for large-scale apps:

### 1. Solving "Initialization Hell" (Key Difference)
Riverpod providers are typically lazy. If you have a dependency chain like `Auth -> Network -> Config` where each requires asynchronous initialization (`init()`), managing the initialization order in Riverpod often involves complex `futureProvider` chains or manual loading states.

**Modularity** solves this by building a **Dependency Acyclic Graph (DAG)**. It guarantees that your module's `onInit()` runs **only after** all imported modules are fully initialized.
> *You simply define `imports => [ApiModule]`, and the framework ensures the API is ready before your module starts.*

### 2. Formalized Lifecycle
Riverpod's lifecycle is usually tied to listeners (e.g., `autoDispose`).
**Modularity** provides explicit states: `initial` -> `loading` -> `loaded` -> `disposed`.

This allows you to:
*   **Deterministically** run heavy logic on start (socket connections, cache warmup).
*   **Correctly** release resources when the module is disposed, tied specifically to the Navigation Stack (e.g., when the module's scope is popped).

### 3. Strict Isolation
In a typical Riverpod setup, providers are often globally accessible.
**Modularity** enforces strict boundaries:
*   `imports`: What your module needs.
*   `exports`: What your module shares with others.

This prevents "spaghetti dependencies" in Enterprise applications—Module B cannot access Module A's internal services unless Module A explicitly exports them.

### 4. Synergy (How it works)
Use **Modularity** for macro-architecture (Global Services, Feature Modules, Routing), and **Riverpod** for local widget state management.

**The Pattern:**
1.  **Modularity** creates and initializes core services (Repositories, API Clients).
2.  Pass these initialized instances to **Riverpod** via `ProviderScope` overrides.

```dart
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 1. Resolve the ready-to-use service from Modularity
    final authService = ModuleProvider.of(context).get<AuthService>();

    // 2. Inject it into Riverpod
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
      ],
      child: const _CounterView(),
    );
  }
}
```

## Summary

*   **Use Riverpod only**: For small/medium apps or when you don't have complex asynchronous initialization chains between features.
*   **Use Modularity + Riverpod**: For Enterprise apps requiring strict module boundaries, guaranteed initialization order, and explicit memory management.

