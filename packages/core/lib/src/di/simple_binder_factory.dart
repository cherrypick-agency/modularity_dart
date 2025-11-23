import 'package:modularity_contracts/modularity_contracts.dart';
import 'simple_binder.dart';

class SimpleBinderFactory implements BinderFactory {
  @override
  Binder create([Binder? parent]) {
    return SimpleBinder(parent: parent);
  }
}
