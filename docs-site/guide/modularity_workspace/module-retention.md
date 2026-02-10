# Module Retention Policies

This document explains how `ModuleScope` manages the lifetime of modules—when they stay alive and when they are disposed.

## Overview

Every `ModuleScope` can be configured with a `ModuleRetentionPolicy`. The policy determines **when the underlying `ModuleController` is disposed**:

| Policy | Behaviour |
|--------|-----------|
| `routeBound` (default) | Dispose when the owning route is popped from the navigator stack |
| `keepAlive` | Cache the controller; it survives widget unmounts and can be reused |
| `strict` | Dispose immediately when `ModuleScope` leaves the widget tree |

## Quick usage

```dart
ModuleScope(
  module: ProfileModule(),
  retentionPolicy: ModuleRetentionPolicy.keepAlive,
  retentionKey: 'profile-${user.id}', // optional explicit key
  child: ProfileView(),
)
```

If you omit `retentionPolicy`, the default is `routeBound`.

---

## Policy details

### routeBound

```dart
ModuleRetentionPolicy.routeBound
```

The module stays alive while the route is on the navigator stack. When the route is **popped** (user presses back, `Navigator.pop`, etc.), the module is disposed.

- Uses Flutter's `RouteObserver` under the hood.
- Suitable for feature screens tied to navigation (e.g., order details, checkout).
- If the same widget unmounts but the route remains on the stack, the module is **not** disposed.

### keepAlive

```dart
ModuleRetentionPolicy.keepAlive
```

The controller is registered in a global `ModuleRetainer` and survives across widget unmounts. When the same `ModuleScope` (identified by `retentionKey`) is mounted again, it **reuses** the existing controller instead of creating a new one.

Use cases:
- Tabs that should preserve state when switching.
- Cached data modules (e.g., user profile, shopping cart).
- Long-lived background services.

The controller is disposed when:
1. All scopes that acquired the same key have been disposed **and** `release` was called (reference count drops to zero).
2. You explicitly call `ModuleRetainer.evict(key)`.

### strict

```dart
ModuleRetentionPolicy.strict
```

Dispose as soon as the `ModuleScope` widget leaves the tree—no caching, no route observation. This is the simplest model: one widget instance = one controller lifetime.

Use cases:
- Ephemeral dialogs or bottom sheets.
- Widgets that must not share state across rebuilds.

---

## Retention keys

A **retention key** uniquely identifies a cached controller. If two `ModuleScope` widgets share the same key and policy `keepAlive`, they share the controller.

### Automatic key derivation

If you don't supply `retentionKey`, Modularity derives one from:

1. `module.runtimeType`
2. Current route name/path (`ModalRoute.of(context).settings.name`)
3. Hash of `args` passed to the module
4. Parent scope key (for nested modules)
5. Optional `retentionExtras` map

This is usually enough for pages tied to a route. For dynamic scenarios (e.g., multiple instances of the same module type on one page), provide an explicit key.

### Explicit key

```dart
ModuleScope(
  module: ChatModule(),
  retentionPolicy: ModuleRetentionPolicy.keepAlive,
  retentionKey: 'chat-room-$roomId',
  child: ChatView(),
)
```

### Custom key via `RetentionIdentityProvider`

A module can implement the `RetentionIdentityProvider` mixin to compute its own key:

```dart
class ChatModule extends Module with RetentionIdentityProvider {
  final String roomId;
  ChatModule(this.roomId);

  @override
  Object? buildRetentionIdentity(ModuleRetentionContext context) {
    return 'chat-room-$roomId';
  }

  @override
  void binds(Binder i) { /* ... */ }
}
```

If `buildRetentionIdentity` returns `null`, the default derivation is used.

---

## ModuleRetainer API

`ModuleRetainer` is stored in `ModularityRoot` and manages the cache for `keepAlive` modules.

| Method | Description |
|--------|-------------|
| `acquire(key)` | Increment ref count and return the controller (or `null` if not registered) |
| `register(key, controller)` | Store a new controller with ref count = 1 |
| `release(key)` | Decrement ref count; optionally dispose if orphaned |
| `evict(key)` | Remove and dispose the controller unconditionally |
| `peek(key)` | Return controller without changing ref count |
| `debugSnapshot()` | Get a list of all entries for diagnostics |

Typically you don't call these directly—`ModuleScope` handles them via its strategy.

---

## Strategies under the hood

Each policy maps to an internal `ModuleRetentionStrategy`:

| Policy | Strategy class |
|--------|---------------|
| `routeBound` | `RouteBoundRetentionStrategy` |
| `keepAlive` | `KeepAliveRetentionStrategy` |
| `strict` | `StrictRetentionStrategy` |

Strategies implement:
- `reuseExisting()` – try to acquire a cached controller.
- `onControllerCreated(controller)` – register with retainer if needed.
- `onStateDispose()` – handle widget unmount.
- `disposeNow()` – force-dispose (e.g., route pop).
- `onRetry()` – handle error retry flow.
- `didChangeDependencies()` – subscribe to route observer, etc.

---

## Debugging

Use `ModuleRetainer.debugSnapshot()` to inspect cached modules:

```dart
final retainer = ModularityRoot.retainerOf(context);
for (final entry in retainer.debugSnapshot()) {
  print('${entry.moduleType} key=${entry.key} refs=${entry.refCount}');
}
```

---

## FAQ

**When should I use `keepAlive` vs `routeBound`?**
Use `keepAlive` when the same module instance must survive tab switches or widget rebuilds. Use `routeBound` when the module's lifetime should follow navigation.

**Can I force-dispose a `keepAlive` module?**
Yes. Call `ModuleRetainer.evict(key)` or navigate away so that all scopes release their references.

**What happens if I change `retentionPolicy` at runtime?**
An assertion will fire in debug mode. Policies cannot be changed on an existing `ModuleScope`; rebuild with a new key/widget instead.

**How do nested modules derive their key?**
Child modules receive the parent's key via `_RetentionKeyScope`, so their derived keys include the parent namespace automatically.

