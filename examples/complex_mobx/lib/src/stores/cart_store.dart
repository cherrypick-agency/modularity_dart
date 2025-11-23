import 'package:mobx/mobx.dart';
import '../domain/entities.dart';

part 'cart_store.g.dart';

class CartStore = _CartStore with _$CartStore;

abstract class _CartStore with Store {
  @observable
  ObservableList<Product> items = ObservableList<Product>();

  @computed
  int get itemCount => items.length;

  @computed
  double get totalPrice => items.fold(0, (sum, item) => sum + item.price);

  @action
  void add(Product product) {
    items.add(product);
  }

  @action
  void remove(Product product) {
    items.remove(product);
  }

  @action
  void clear() {
    items.clear();
  }
}

