import 'dart:async';
import 'package:modularity_contracts/modularity_contracts.dart';

class AuthService {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> login() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isLoggedIn = true;
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isLoggedIn = false;
  }
}

class AuthModule extends Module {
  @override
  void binds(Binder i) {
    // Internal dependencies for AuthModule would go here
  }

  @override
  void exports(Binder i) {
    // Public dependencies exposed to importers
    i.registerLazySingleton<AuthService>(() => AuthService());
  }
}
