import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../auth/auth_module.dart';
import '../profile/profile_module.dart';

class HomeModule extends Module {
  @override
  List<Module> get imports => [
    AuthModule(), 
  ];

  @override
  List<Module> get submodules => [
    ProfileModule(),
  ];

  @override
  void binds(Binder i) {
    // Home logic here if needed
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final binder = ModuleProvider.of(context);
    final authService = binder.get<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome! Logged in: ${authService.isLoggedIn}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await authService.login();
                (context as Element).markNeedsBuild(); // Hack for simplicity in this demo
              },
              child: const Text('Login'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ModuleScope(
                      module: ProfileModule(),
                      child: const ProfilePage(),
                    ),
                  ),
                );
              },
              child: const Text('Go to Profile (Requires Auth)'),
            ),
          ],
        ),
      ),
    );
  }
}
