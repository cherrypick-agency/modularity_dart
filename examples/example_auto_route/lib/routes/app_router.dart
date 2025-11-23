import 'package:auto_route/auto_route.dart';

import '../modules/root/root_module.dart';
import 'app_router.gr.dart';

export 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  final AuthService authService;
  AppRouter(this.authService);

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
  final AuthService authService;
  AuthGuard(this.authService);

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (authService.isLoggedIn) {
      resolver.next(true);
    } else {
      router.push(const AuthRoute());
    }
  }
}
