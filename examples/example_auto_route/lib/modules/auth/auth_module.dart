import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../root/root_module.dart';
import '../../routes/app_router.dart';

class AuthModule extends Module {
  @override
  List<Type> get expects => [AuthService];

  @override
  void binds(Binder i) {}
}

@RoutePage()
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: AuthModule(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              ModuleProvider.of(context).get<AuthService>().login();
              context.router.replace(const DashboardRoute());
            },
            child: const Text('Login'),
          ),
        ),
      ),
    );
  }
}

