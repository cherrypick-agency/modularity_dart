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
            // We use Builder to ensure context has access to RootModule
            // This allows AppRouter.redirect to find AuthService
            return MaterialApp.router(
              title: 'GoRouter Example',
              routerConfig: AppRouter.router,
            );
          },
        ),
      ),
    );
  }
}


