import 'package:modularity_contracts/modularity_contracts.dart';
import 'get_it_binder.dart';

class GetItBinderFactory implements BinderFactory {
  final bool useGlobalInstance;

  const GetItBinderFactory({
    this.useGlobalInstance = false,
  });

  @override
  Binder create([Binder? parent]) {
    return GetItBinder(parent, useGlobalInstance);
  }
}
