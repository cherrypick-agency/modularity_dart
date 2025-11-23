import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../../stores/cart_store.dart';

class CartModule extends Module {
  @override
  List<Type> get expects => [CartStore];

  @override
  void binds(Binder i) {}
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cartStore = ModuleProvider.of(context).get<CartStore>();

    return Scaffold(
      appBar: AppBar(
        title: Observer(
          builder: (_) => Text('Cart (\$${cartStore.totalPrice.toStringAsFixed(2)})'),
        ),
      ),
      body: Observer(
        builder: (_) {
          if (cartStore.items.isEmpty) {
            return const Center(child: Text('Cart is empty'));
          }
          return ListView.builder(
            itemCount: cartStore.items.length,
            itemBuilder: (context, index) {
              final item = cartStore.items[index];
              return ListTile(
                title: Text(item.name),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle),
                  onPressed: () => cartStore.remove(item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

