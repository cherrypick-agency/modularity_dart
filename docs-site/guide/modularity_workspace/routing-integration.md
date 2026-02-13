# Routing Integration

Wrap each route in a `ModuleScope` so modules follow navigation lifecycle automatically. Modularity is router-agnostic -- the same pattern works with GoRouter, AutoRoute, or Navigator 1.0.

## Core Pattern

One route = one `ModuleScope`. The scope creates a `ModuleController`, runs `binds()` / `exports()` / `onInit()`, and disposes the controller when the route is removed.

```dart
ModuleScope(
  module: ProfileModule(),
  child: const ProfilePage(),
)
```

`ModuleScope` handles:
- Creating a `Binder` scoped to this module
- Running `binds()`, `exports()`, `onInit()`
- Disposing the controller when the route leaves the stack

```mermaid
flowchart TB
    MR[ModularityRoot] --> RS[RootModule scope]
    RS --> Auth[AuthModule scope<br/>/login]
    RS --> Home[HomeModule scope<br/>/home]
    Home --> Details[DetailsModule scope<br/>/home/details/:id]
```

### Scope chaining

Nested `ModuleScope` widgets form a parent-child chain. Child scopes can resolve dependencies registered by any ancestor scope via `get<T>()`:

```
ModularityRoot
  +-- ModuleScope<RootModule>       <- registers AuthService
        +-- MaterialApp.router
              +-- ModuleScope<HomeModule>  <- get<AuthService>() resolves from parent
```

### Configurable modules

Pass route parameters into modules using the `Configurable<T>` interface and the `args` parameter. `configure()` runs before `binds()`:

```dart
class DetailsModule extends Module implements Configurable<String> {
  late String id;

  @override
  void configure(String args) {
    id = args;
  }

  @override
  void binds(Binder i) {
    i.registerLazySingleton<DetailsRepository>(
      () => DetailsRepository(id: id),
    );
  }
}
```

```dart
ModuleScope(
  module: DetailsModule(),
  args: routeParams['id'],
  child: const DetailsPage(),
)
```

### Expected dependencies

Declare parent dependencies a module requires with `expects`. Initialization fails fast if a listed type is missing from the parent scope:

```dart
class SettingsModule extends Module {
  @override
  List<Type> get expects => [AuthService];

  @override
  void binds(Binder i) {}
}
```

## Observer Registration

`ModularityRoot` accepts an `observer` parameter -- a `RouteObserver<ModalRoute>` that powers the `routeBound` retention policy. Pass the same observer to both `ModularityRoot` and your router so module controllers dispose when their route is popped.

::: warning
Without a properly registered observer, `routeBound` retention cannot detect route pops. Controllers will only dispose when the widget itself is unmounted. Always register the observer at the app level.
:::

## GoRouter

### App setup

Place `ModularityRoot` and a root `ModuleScope` above the router. Pass the observer to both `ModularityRoot` and the router:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      observer: AppRouter.observer,
      child: ModuleScope(
        module: RootModule(),
        child: Builder(
          builder: (context) {
            return MaterialApp.router(
              routerConfig: AppRouter.router,
            );
          },
        ),
      ),
    );
  }
}
```

### Route definitions

Wrap the `builder` return value in a `ModuleScope`:

```dart
final router = GoRouter(
  initialLocation: '/home',
  observers: [AppRouter.observer],
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => ModuleScope(
        module: AuthModule(),
        child: const AuthPage(),
      ),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => ModuleScope(
        module: HomeModule(),
        child: const HomePage(),
      ),
      routes: [
        GoRoute(
          path: 'details/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ModuleScope(
              module: DetailsModule(),
              args: id,
              child: const DetailsPage(),
            );
          },
        ),
      ],
    ),
  ],
);
```

### ShellRoute (tab layout)

A `ShellRoute` keeps a shared layout alive while child routes swap. Wrap the shell builder in its own `ModuleScope`:

```dart
ShellRoute(
  builder: (context, state, child) {
    return ModuleScope(
      module: DashboardModule(),
      child: DashboardPage(child: child),
    );
  },
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => ModuleScope(
        module: HomeModule(),
        child: const HomePage(),
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => ModuleScope(
        module: SettingsModule(),
        child: const SettingsPage(),
      ),
    ),
  ],
)
```

`DashboardModule`'s scope becomes the parent for `HomeModule` and `SettingsModule`. Dependencies registered in the dashboard are available to both child scopes.

### Redirect with ModuleProvider

Access dependencies registered by an ancestor `ModuleScope` inside `redirect`:

```dart
GoRouter(
  redirect: (BuildContext context, GoRouterState state) {
    try {
      final authService =
          ModuleProvider.of(context).get<AuthService>();
      final isLoggedIn = authService.isLoggedIn;
      final isLoggingIn = state.uri.path == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/home';
    } catch (_) {
      // AuthService not yet available during first build
    }
    return null;
  },
  // ...
);
```

The `redirect` callback receives a `BuildContext` that sits below `ModularityRoot` and the root `ModuleScope`. The `Builder` wrapper in the app setup creates this context.

## AutoRoute

### App setup

With AutoRoute, the router object is created in the `Builder` callback so that resolved dependencies (like `AuthService`) can be passed to guards. Use `ModularityRoot.observerOf(context)` to access the observer:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      child: ModuleScope(
        module: RootModule(),
        child: Builder(
          builder: (context) {
            final authService =
                ModuleProvider.of(context).get<AuthService>();
            final appRouter = AppRouter(authService);

            return MaterialApp.router(
              routerConfig: appRouter.config(
                navigatorObservers: () => [
                  ModularityRoot.observerOf(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
```

AutoRoute registers the observer through `config(navigatorObservers: ...)` rather than the `MaterialApp` constructor.

### Route pages with ModuleScope

Wrap `ModuleScope` inside `@RoutePage()` widgets:

```dart
@RoutePage()
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: HomeModule(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: const HomeContent(),
      ),
    );
  }
}
```

Co-locate `ModuleScope` with its route page. Place it inside the page widget rather than in route configuration.

### Router configuration and guards

```dart
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  AppRouter(this.authService);
  final AuthService authService;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: AuthRoute.page, path: '/login'),
    AutoRoute(
      page: DashboardRoute.page,
      path: '/',
      guards: [AuthGuard(authService)],
      children: [
        AutoRoute(page: HomeRoute.page, path: 'home'),
        AutoRoute(page: SettingsRoute.page, path: 'settings'),
      ],
    ),
    AutoRoute(
      page: DetailsRoute.page,
      path: '/details/:id',
      guards: [AuthGuard(authService)],
    ),
  ];
}

class AuthGuard extends AutoRouteGuard {
  AuthGuard(this.authService);
  final AuthService authService;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (authService.isLoggedIn) {
      resolver.next(true);
    } else {
      router.push(const AuthRoute());
    }
  }
}
```

### Tab navigation

Use `AutoTabsScaffold` inside a `ModuleScope` for tabbed layouts:

```dart
@RoutePage()
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: DashboardModule(),
      child: AutoTabsScaffold(
        routes: const [HomeRoute(), SettingsRoute()],
        bottomNavigationBuilder: (_, tabsRouter) {
          return BottomNavigationBar(
            currentIndex: tabsRouter.activeIndex,
            onTap: tabsRouter.setActiveIndex,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home), label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings',
              ),
            ],
          );
        },
      ),
    );
  }
}
```

### Configurable route pages

Pass path parameters via `args`:

```dart
@RoutePage()
class DetailsPage extends StatelessWidget {
  const DetailsPage({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: DetailsModule(),
      args: id,
      child: Scaffold(
        appBar: AppBar(title: Text('Details $id')),
        body: const DetailsContent(),
      ),
    );
  }
}
```

## Retention Policies

`ModuleScope` defaults to `ModuleRetentionPolicy.routeBound`. Three policies are available:

| Policy | Behavior |
|--------|----------|
| `routeBound` (default) | Controller disposed when the route pops. |
| `strict` | Controller disposed on every widget unmount. |
| `keepAlive` | Controller cached in `ModuleRetainer`, survives widget unmount. |

### routeBound

The default. The `RouteBoundRetentionStrategy` subscribes to the enclosing `ModalRoute` via the `RouteObserver` from `ModularityRoot` and disposes the controller when the route is popped or removed.

```dart
ModuleScope(
  module: ProfileModule(),
  retentionPolicy: ModuleRetentionPolicy.routeBound,
  child: const ProfilePage(),
)
```

### keepAlive

Cache the controller in `ModuleRetainer` so it survives widget unmounts. Useful for modules with expensive initialization (network calls, database setup).

```dart
ModuleScope(
  module: ExpensiveModule(),
  retentionPolicy: ModuleRetentionPolicy.keepAlive,
  retentionKey: 'expensive-module',
  child: const ExpensivePage(),
)
```

The controller is evicted when its route terminates or when explicitly evicted from the retainer.

### Retention key for route parameters

When the same module type is used on different routes with different parameters, set a `retentionKey` to avoid cache collisions:

```dart
GoRoute(
  path: '/users/:id',
  builder: (context, state) {
    final userId = state.pathParameters['id']!;
    return ModuleScope(
      module: UserModule(),
      args: userId,
      retentionPolicy: ModuleRetentionPolicy.keepAlive,
      retentionKey: 'user-$userId',
      child: const UserPage(),
    );
  },
)
```

Without an explicit key, the identity is derived from `(moduleType, route, args)`. Set `retentionKey` when you need deterministic cache identity.

::: warning
`overrideScope` does **not** affect the retention key. Two scopes with the same key but different overrides share one cached controller. Include override identity in the key if needed:
```dart
retentionKey: 'my-module-${identityHashCode(overrideScope)}',
```
:::

## Loading and Error States

`ModuleScope` renders loading/error UI while the module initializes:

```dart
ModuleScope(
  module: PaymentModule(),
  loadingBuilder: (_) => const PaymentSkeleton(),
  errorBuilder: (_, error, retry) => PaymentErrorView(
    message: error.toString(),
    onRetry: retry,
  ),
  child: const PaymentPage(),
)
```

Fallback order: scope builder -> `ModularityRoot` defaults -> built-in placeholder.

## Debug Logging

Enable lifecycle logging to trace module creation and disposal:

```dart
ModularityRoot(
  lifecycleLogger: kDebugMode ? ModularityRoot.defaultDebugLogger : null,
  observer: observer,
  child: MaterialApp(
    navigatorObservers: [observer],
    // ...
  ),
)
```

Output:

```
[Modularity] CREATED HomeModule key=HomeModule@/home
[Modularity] DISPOSED HomeModule key=HomeModule@/home
```

## Checklist

| Concern | Solution |
|---------|----------|
| Per-route DI scope | Wrap page content in `ModuleScope` |
| Route parameters | `Configurable<T>` + `ModuleScope.args` |
| Route-aware disposal | `ModularityRoot(observer: ...)` + `routeBound` policy |
| Cross-tab caching | `keepAlive` policy + `retentionKey` |
| Scope chaining | Nested `ModuleScope` widgets |
| GoRouter observer | `GoRouter(observers: [AppRouter.observer])` |
| AutoRoute observer | `appRouter.config(navigatorObservers: () => [ModularityRoot.observerOf(context)])` |
| Root-level services | `RootModule` above the router |
| Parent dependencies | Declare `expects` in child modules |
