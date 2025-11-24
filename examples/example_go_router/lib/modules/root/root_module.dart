import 'package:modularity_flutter/modularity_flutter.dart';

class AuthService {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  void login() => _isLoggedIn = true;
  void logout() => _isLoggedIn = false;
}

class RootModule extends Module {
  @override
  void binds(Binder i) {
    i.singleton<AuthService>(() => AuthService());
  }
}
