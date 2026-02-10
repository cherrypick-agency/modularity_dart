import 'package:modularity_core/modularity_core.dart';

class AuthService {
  void login() => print('Logged in');
}

class AuthModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton(() => AuthService());
  }
}

void main() {
  // 1. Create the binder factory (usually one per app)
  final factory = SimpleBinderFactory();

  // 2. Create the root binder
  final rootBinder = factory.create();

  // 3. Register your modules
  final authModule = AuthModule();
  authModule.binds(rootBinder);

  // 4. Use the dependencies
  final authService = rootBinder.get<AuthService>();
  authService.login();
}
