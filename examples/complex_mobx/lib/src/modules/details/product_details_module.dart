import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../../domain/entities.dart';
import '../../stores/cart_store.dart';

class ProductDetailsModule extends Module implements Configurable<Product> {
  late Product _product;

  // Test Tracker
  static bool wasDisposed = false;
  static bool wasInit = false;

  ProductDetailsModule();

  @override
  void configure(Product args) {
    _product = args;
  }

  @override
  List<Type> get expects => [CartStore];

  @override
  void binds(Binder i) {
    // Local dependency
    i.singleton<String>(() => "Details for ${_product.name}");
  }

  @override
  Future<void> onInit() async {
    wasInit = true;
    wasDisposed = false;
  }

  @override
  void onDispose() {
    wasDisposed = true;
    print('ProductDetailsModule Disposed!');
  }
}

class ProductDetailsPage extends StatelessWidget {
  const ProductDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final binder = ModuleProvider.of(context);
    final cartStore = binder.get<CartStore>();
    final title = binder.get<String>();

    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Observer(
              builder: (_) {
                // Check if item is in cart using the parent store
                final isInCart =
                    cartStore.items.any((i) => title.contains(i.name));
                return isInCart
                    ? const Text("Already in Cart",
                        style: TextStyle(color: Colors.green))
                    : const Text("Not in Cart");
              },
            )
          ],
        ),
      ),
    );
  }
}
