import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../../stores/auth_store.dart';
import '../auth/auth_module.dart';
import '../debug/debug_module.dart';

class SettingsModule extends Module {
  @override
  List<Type> get expects => [AuthStore];

  @override
  void binds(Binder i) {}
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showDebug = false;

  @override
  Widget build(BuildContext context) {
    final authStore = ModuleProvider.of(context).get<AuthStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Observer(
              builder: (_) =>
                  Text('User: ${authStore.user?.username ?? "Guest"}'),
            ),
            const SizedBox(height: 20),

            // Strict Disposal Test Toggle
            SwitchListTile(
              key: const Key('debug_toggle'),
              title: const Text('Show Debug Panel'),
              value: _showDebug,
              onChanged: (v) => setState(() => _showDebug = v),
            ),

            if (_showDebug)
              ModuleScope(
                module: DebugModule(),
                child: const DebugWidget(),
              ),

            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('logout_btn'),
              onPressed: () {
                authStore.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => ModuleScope(
                      module: AuthModule(),
                      child: const LoginPage(),
                    ),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
