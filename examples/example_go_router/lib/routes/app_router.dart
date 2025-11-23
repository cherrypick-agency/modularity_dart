import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../modules/auth/auth_module.dart';
import '../modules/dashboard/dashboard_module.dart';
import '../modules/details/details_module.dart';
import '../modules/home/home_module.dart';
import '../modules/root/root_module.dart';
import '../modules/settings/settings_module.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    observers: [Modularity.observer],
    redirect: (BuildContext context, GoRouterState state) {
      // Access AuthService from RootModule
      // Since MaterialApp.router is wrapped in ModuleScope<RootModule>, we can access it.
      // However, accessing inherited widgets in redirect can be tricky if context is not fully built or if it's strict.
      // But usually it works if the router is a child of the provider.
      try {
        final authService = ModuleProvider.of(context).get<AuthService>();
        final isLoggedIn = authService.isLoggedIn;
        final isLoggingIn = state.uri.path == '/login';

        if (!isLoggedIn && !isLoggingIn) return '/login';
        if (isLoggedIn && isLoggingIn) return '/home';
      } catch (e) {
        // If AuthService is not found (e.g. during hot reload or init issues), default to login
        // return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => ModuleScope(
          module: AuthModule(),
          child: const AuthPage(),
        ),
      ),
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
            routes: [
              GoRoute(
                path: 'details/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ModuleScope(
                    module: DetailsModule(),
                    args: id, // <-- Configurable
                    child: DetailsPage(id: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => ModuleScope(
              module: SettingsModule(),
              child: const SettingsPage(),
            ),
          ),
        ],
      ),
    ],
  );
}
