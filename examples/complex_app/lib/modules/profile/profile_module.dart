import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../auth/auth_module.dart';

class ProfileModule extends Module {
  @override
  List<Type> get expects => [AuthService]; // Must be provided by parent/imports

  @override
  void binds(Binder i) {
    // Profile specific bindings
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final binder = ModuleProvider.of(context);
    
    // Access parent dependency securely
    // If AuthService wasn't found, this would throw, but 'expects' guarantees it.
    // However, binder.get searches Imports and Local. 
    // To search PARENT we use binder.parent<T>().
    // BUT: If we imported AuthModule in HomeModule, and HomeModule is parent of ProfileModule,
    // is AuthService available?
    // 
    // HomeModule IMPORTS AuthModule. So AuthModule public exports are available to HomeModule.
    // ProfileModule is a CHILD of HomeModule (nested widget).
    // So ProfileModule's parent binder is HomeModule's binder.
    // HomeModule's binder can see AuthModule's exports.
    // So binder.parent<AuthService>() should work!
    
    final authService = binder.parent<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('User Profile'),
            Text('Is Logged In: ${authService.isLoggedIn}'),
          ],
        ),
      ),
    );
  }
}

