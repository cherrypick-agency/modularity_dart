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
            final authService = ModuleProvider.of(context).get<AuthService>();
            final appRouter = AppRouter(authService);

            return MaterialApp.router(
              title: 'AutoRoute Example',
              routerConfig: appRouter.config(
                navigatorObservers: () => [ModularityRoot.observerOf(context)],
              ),
            );
          },
        ),
      ),
    );
  }
}
