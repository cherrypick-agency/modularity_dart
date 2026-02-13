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
      observer: AppRouter.observer,
      child: ModuleScope(
        module: RootModule(),
        child: Builder(
          builder: (context) {
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
