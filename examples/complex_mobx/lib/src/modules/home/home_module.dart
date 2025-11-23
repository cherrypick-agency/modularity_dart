import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../../stores/product_store.dart';
import '../../stores/cart_store.dart';
import '../../domain/entities.dart';
import '../details/product_details_module.dart';

class HomeModule extends Module {
  @override
  List<Module> get submodules => [
    ProductDetailsModule(),
  ];

  @override
  List<Type> get expects => [CartStore];

  @override
  void binds(Binder i) {
    i.singleton<ProductStore>(() => ProductStore());
  }

  @override
  Future<void> onInit() async {
    // We could load products here, but let's do it in UI or store init
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ProductStore productStore;
  late final CartStore cartStore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final binder = ModuleProvider.of(context);
    productStore = binder.get<ProductStore>();
    cartStore = binder.get<CartStore>();
    
    // Auto load
    if (productStore.products.isEmpty) {
      productStore.loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: Observer(
        builder: (_) {
          if (productStore.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: productStore.products.length,
            itemBuilder: (context, index) {
              final product = productStore.products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text('\$${product.price}'),
                onTap: () {
                  // Navigate to Details Module
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ModuleScope(
                        module: ProductDetailsModule(),
                        args: product, // Passed to configure()
                        child: const ProductDetailsPage(),
                      ),
                    ),
                  );
                },
                trailing: IconButton(
                  key: Key('add_${product.id}'),
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () => cartStore.add(product),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
