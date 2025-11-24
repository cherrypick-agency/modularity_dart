import 'package:modularity_contracts/modularity_contracts.dart';
import 'get_it_binder.dart';

class GetItBinderFactory implements BinderFactory {
  @override
  Binder create([Binder? parent]) {
    return GetItBinder(parent);
  }
}

