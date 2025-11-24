import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:modularity_cli/modularity_cli.dart';
import 'package:flutter_test/flutter_test.dart';

// --- MOCK APP ARCHITECTURE ---

class NetworkModule extends Module {
  @override
  void binds(Binder i) {}
}

class AnalyticsModule extends Module {
  @override
  void binds(Binder i) {}
}

class AuthFeature extends Module {
  @override
  List<Module> get imports => [NetworkModule()]; // Dependency

  @override
  void binds(Binder i) {}
}

class CartFeature extends Module {
  @override
  void binds(Binder i) {}
}

class CheckoutFeature extends Module {
  @override
  List<Module> get imports => [CartFeature(), NetworkModule()];

  @override
  void binds(Binder i) {}
}

class ProductDetailsFeature extends Module implements Configurable<int> {
  late int productId;

  // Empty constructor for static graph
  ProductDetailsFeature();

  @override
  void configure(int args) {
    productId = args;
  }

  @override
  void binds(Binder i) {}
}

class ProductListFeature extends Module {
  @override
  List<Module> get submodules => [
        ProductDetailsFeature(), // Composition: List owns Details
      ];

  @override
  void binds(Binder i) {}
}

class ShopFeature extends Module {
  @override
  List<Module> get submodules => [
        ProductListFeature(),
        CartFeature(),
        CheckoutFeature(),
      ];

  @override
  List<Module> get imports => [AnalyticsModule()];

  @override
  void binds(Binder i) {}
}

class AccountFeature extends Module {
  @override
  List<Module> get imports => [AuthFeature()];

  @override
  void binds(Binder i) {}
}

class AppModule extends Module {
  @override
  List<Module> get submodules => [
        ShopFeature(),
        AccountFeature(),
        AuthFeature(),
      ];

  @override
  List<Module> get imports => [
        NetworkModule(),
        AnalyticsModule(),
      ];

  @override
  void binds(Binder i) {}
}

void main() {
  test('Generate Enterprise Architecture Demo', () async {
    print('Generating Big Architecture Diagram...');
    await GraphVisualizer.visualize(AppModule());
  });
}
