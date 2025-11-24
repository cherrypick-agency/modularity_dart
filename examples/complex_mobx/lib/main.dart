import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'src/modules/root/root_module.dart';
import 'src/modules/auth/auth_module.dart';

void main() {
  runApp(const ComplexApp());
}

class ComplexApp extends StatelessWidget {
  const ComplexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      child: ModuleScope(
        module: RootModule(),
        child: MaterialApp(
          title: 'Complex MobX Shop',
          navigatorObservers: [Modularity.observer],
          theme: ThemeData(
            useMaterial3: true,
            primarySwatch: Colors.blue,
          ),
          home: ModuleScope(
            module: AuthModule(),
            child: const LoginPage(),
          ),
        ),
      ),
    );
  }
}
