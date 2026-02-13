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
  static final observer = RouteObserver<ModalRoute<dynamic>>();

  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    observers: [observer],
    redirect: (BuildContext context, GoRouterState state) {
      try {
        final authService = ModuleProvider.of(context).get<AuthService>();
        final isLoggedIn = authService.isLoggedIn;
        final isLoggingIn = state.uri.path == '/login';

        if (!isLoggedIn && !isLoggingIn) return '/login';
        if (isLoggedIn && isLoggingIn) return '/home';
      } catch (e) {
        // If AuthService is not found, default behavior
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            ModuleScope(module: AuthModule(), child: const AuthPage()),
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
            builder: (context, state) =>
                ModuleScope(module: HomeModule(), child: const HomePage()),
            routes: [
              GoRoute(
                path: 'details/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ModuleScope(
                    module: DetailsModule(),
                    args: id,
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
