import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../../stores/auth_store.dart';
import '../../stores/cart_store.dart';
import '../home/home_module.dart';
import '../cart/cart_module.dart';
import '../settings/settings_module.dart';

class MainModule extends Module {
  @override
  List<Module> get submodules => [
    HomeModule(),
    CartModule(),
    SettingsModule(),
  ];

  @override
  List<Type> get expects => [AuthStore, CartStore];

  @override
  void binds(Binder i) {}
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  // Nested Modules are created once and kept alive by IndexedStack
  // However, we need to wrap them in ModuleScope.
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ModuleScope(
            module: HomeModule(),
            child: const HomePage(),
          ),
          ModuleScope(
            module: CartModule(),
            child: const CartPage(),
          ),
          ModuleScope(
            module: SettingsModule(),
            child: const SettingsPage(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
