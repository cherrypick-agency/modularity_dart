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
    i.singleton<AuthService>(() => AuthService());
  }
}

