import 'package:modularity_flutter/modularity_flutter.dart';
import '../../stores/auth_store.dart';
import '../../stores/cart_store.dart';
import '../auth/auth_module.dart';
import '../main/main_module.dart';

class RootModule extends Module {
  @override
  List<Module> get submodules => [
        AuthModule(),
        MainModule(),
      ];

  @override
  void binds(Binder i) {
    // GLOBAL SINGLETONS
    i.singleton<AuthStore>(() => AuthStore());
    i.singleton<CartStore>(() => CartStore());
  }
}
