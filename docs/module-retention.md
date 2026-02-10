# Module Retention

Control how long a `ModuleController` lives relative to the widget tree and navigation stack.

## Retention Policies

Every `ModuleScope` accepts a `retentionPolicy` parameter. Three policies are available:

| Policy | Disposed when | Caches across unmounts |
|--------|--------------|----------------------|
| `routeBound` (default) | Route is popped or removed | No |
| `keepAlive` | All references released **or** route terminates | Yes |
| `strict` | `ModuleScope` leaves the widget tree | No |

```dart
ModuleScope(
  module: ProfileModule(),
  retentionPolicy: ModuleRetentionPolicy.keepAlive,
  retentionKey: 'profile-${user.id}',
  child: ProfileView(),
)
```

## routeBound

```dart
ModuleRetentionPolicy.routeBound
```

The controller lives as long as the enclosing `ModalRoute` remains on the navigator stack. Disposal happens on `didPop` or `didRemove`.

Internally, `RouteBoundRetentionStrategy` mixes in `RouteAware` and subscribes to `Modularity.observer`. This means the global `RouteObserver` **must** be registered in your `MaterialApp`:

```dart
MaterialApp(
  navigatorObservers: [Modularity.observer],
  // ...
)
```

Key behaviors:

- Widget unmount without route pop does **not** dispose the controller.
- Each mount creates a fresh controller; no caching between mounts.
- If there is no enclosing `ModalRoute` (e.g. the module is inside a dialog without its own route), the strategy silently skips route subscription.

Best for: feature screens tied to navigation (order details, checkout, profile pages).

## keepAlive

```dart
ModuleRetentionPolicy.keepAlive
```

The controller is registered in the global `ModuleRetainer` (held by `ModularityRoot`). When the `ModuleScope` unmounts, the controller stays in the cache. When a new `ModuleScope` mounts with the same retention key, it reuses the cached controller instead of creating one.

The controller is disposed when:

1. **Reference count drops to zero** -- every mount increments the ref count, every unmount decrements it. When `release()` finds zero references, the controller is disposed.
2. **Route terminates** -- even `keepAlive` controllers track their enclosing route. When the route pops, the controller is evicted automatically.
3. **Explicit eviction** -- call `ModuleRetainer.evict(key)` to force removal regardless of ref count.

Best for: tabs that preserve state, cached data modules (user profile, shopping cart), long-lived background services.

## strict

```dart
ModuleRetentionPolicy.strict
```

Dispose the controller the moment `ModuleScope` leaves the widget tree. No caching, no route observation. One widget instance = one controller lifetime.

Best for: ephemeral dialogs, bottom sheets, widgets that must not share state across rebuilds.

## Retention Keys

A retention key uniquely identifies a cached controller within `ModuleRetainer`. Two `ModuleScope` widgets with the same key and `keepAlive` policy share the same controller.

### Automatic Derivation

When `retentionKey` is not provided, the framework computes one from:

| Input | Source |
|-------|--------|
| Module type | `module.runtimeType` |
| Route name | `ModalRoute.of(context).settings.name` |
| Arguments hash | Stable hash of `args` passed to `ModuleScope` |
| Parent key | Inherited from the nearest ancestor `ModuleScope` via `_RetentionKeyScope` |
| Extras | `retentionExtras` map on `ModuleScope` |

All inputs are combined via `Object.hashAll`. This is sufficient when each route has at most one instance of a given module type.

### Explicit Key

For dynamic scenarios (e.g. multiple chat rooms on one screen), provide an explicit key:

```dart
ModuleScope(
  module: ChatModule(),
  retentionPolicy: ModuleRetentionPolicy.keepAlive,
  retentionKey: 'chat-room-$roomId',
  child: ChatView(),
)
```

### Custom Key via RetentionIdentityProvider

A module can compute its own key by mixing in `RetentionIdentityProvider`:

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

Returning `null` falls back to the default derivation.

> **Retention Key vs Override Scope**
>
> `retentionKey` and `overrideScope` are independent. Two scopes with the same key but different override scopes **share** the cached controller -- the first scope's overrides win. If you need override-aware caching, include the scope identity in the key:
>
> ```dart
> ModuleScope(
>   module: MyModule(),
>   retentionPolicy: ModuleRetentionPolicy.keepAlive,
>   retentionKey: 'my-module-${identityHashCode(overrideScope)}',
>   overrideScope: overrideScope,
>   child: ...,
> )
> ```

## ModuleRetainer API

`ModuleRetainer` is stored in `ModularityRoot` and manages the `keepAlive` cache. Access it via `ModularityRoot.retainerOf(context)`.

| Method | Description |
|--------|-------------|
| `contains(key)` | Check if a controller is cached under `key` |
| `acquire(key)` | Increment ref count and return the controller, or `null` |
| `register(key, controller, ...)` | Store a new controller with initial ref count |
| `release(key, {disposeIfOrphaned})` | Decrement ref count; dispose if orphaned and flag is set |
| `evict(key, {disposeController})` | Remove and optionally dispose the controller unconditionally |
| `peek(key)` | Return the controller without changing ref count |
| `debugSnapshot()` | List all entries as `ModuleRetainerEntrySnapshot` |

You typically do not call these directly -- `ModuleScope` manages them through retention strategies.

## Debugging

Inspect cached modules at runtime:

```dart
final retainer = ModularityRoot.retainerOf(context);
for (final entry in retainer.debugSnapshot()) {
  debugPrint(
    '${entry.moduleType} key=${entry.key} '
    'refs=${entry.refCount} policy=${entry.policy.name}',
  );
}
```

Enable lifecycle logging to trace retention events in the console:

```dart
Modularity.enableDebugLogging();
// Output:
// [Modularity] CREATED ProfileModule key=12345678
// [Modularity] REGISTERED ProfileModule key=12345678 {policy: keepAlive, refCount: 1}
// [Modularity] REUSED ProfileModule key=12345678 {refCount: 2}
// [Modularity] RELEASED ProfileModule key=12345678 {refCount: 1}
```

## Runtime Constraints

- **retentionPolicy cannot change** at runtime. An assertion fires in debug mode if you rebuild a `ModuleScope` with a different policy. Create a new widget instance instead.
- **retentionKey cannot change** at runtime. Same assertion behavior.
- **Nested key scoping** is automatic. Child modules receive the parent's key through `_RetentionKeyScope`, so derived keys include the parent namespace.

## FAQ

**When should I use `keepAlive` vs `routeBound`?**
Use `keepAlive` when the module must survive tab switches or widget rebuilds within the same navigation context. Use `routeBound` when the module's lifetime should match navigation (push = create, pop = dispose).

**Can I force-dispose a `keepAlive` module?**
Yes. Call `ModuleRetainer.evict(key)`. Alternatively, navigate away so that all scopes release their references and the route terminates.

**What happens to `keepAlive` controllers when their route pops?**
They are automatically evicted. The retainer attaches a `route.popped` listener that triggers cleanup, even though the controller would otherwise survive unmounts.
