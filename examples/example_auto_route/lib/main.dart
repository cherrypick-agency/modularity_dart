import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'modules/root/root_module.dart';
import 'routes/app_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      child: ModuleScope(
        module: RootModule(),
        child: Builder(
          builder: (context) {
            // Retrieve AuthService from RootModule
            final authService = ModuleProvider.of(context).get<AuthService>();

            // Initialize AppRouter with AuthService
            // Using a singleton-like behavior for Router in this scope is fine for example
            // Ideally, store this in a StatefulWidget if rebuilds are frequent,
            // but ModuleScope is stable here.
            final appRouter = AppRouter(authService);

            return MaterialApp.router(
              title: 'AutoRoute Example',
              routerConfig: appRouter.config(
                navigatorObservers: () => [Modularity.observer],
              ),
            );
          },
        ),
      ),
    );
  }
}
