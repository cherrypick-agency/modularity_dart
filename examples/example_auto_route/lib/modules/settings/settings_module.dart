import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../root/root_module.dart';
import '../../routes/app_router.dart';

class SettingsModule extends Module {
  @override
  List<Type> get expects => [AuthService];

  @override
  void binds(Binder i) {}
}

@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: SettingsModule(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              ModuleProvider.of(context).get<AuthService>().logout();
              context.router.replaceAll([const AuthRoute()]);
            },
            child: const Text('Logout'),
          ),
        ),
      ),
    );
  }
}
