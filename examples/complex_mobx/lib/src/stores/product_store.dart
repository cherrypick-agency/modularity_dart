import 'package:mobx/mobx.dart';
import '../domain/entities.dart';

part 'product_store.g.dart';

class ProductStore = _ProductStore with _$ProductStore;

abstract class _ProductStore with Store {
  @observable
  ObservableList<Product> products = ObservableList<Product>();

  @observable
  bool isLoading = false;

  @action
  Future<void> loadProducts() async {
    isLoading = true;
    await Future.delayed(const Duration(milliseconds: 300));
    products.clear();
    products.addAll([
      const Product(1, 'Laptop', 999.99),
      const Product(2, 'Phone', 699.99),
      const Product(3, 'Headphones', 199.99),
      const Product(4, 'Watch', 299.99),
    ]);
    isLoading = false;
  }
}

