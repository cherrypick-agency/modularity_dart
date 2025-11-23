import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../../stores/auth_store.dart';
import '../main/main_module.dart';

class AuthModule extends Module {
  @override
  List<Type> get expects => [AuthStore];

  @override
  void binds(Binder i) {}
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authStore = ModuleProvider.of(context).get<AuthStore>();

    return Scaffold(
      body: Center(
        child: Observer(
          builder: (_) {
            if (authStore.isLoading) {
              return const CircularProgressIndicator();
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Login Page'),
                if (authStore.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      authStore.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('login_btn'),
                  onPressed: () async {
                    await authStore.login('user', 'password');
                    if (context.mounted && authStore.isLoggedIn) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => ModuleScope(
                            module: MainModule(),
                            child: const MainPage(),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Login'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
