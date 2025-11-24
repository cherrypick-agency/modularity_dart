import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../root/root_module.dart';

class DetailsModule extends Module implements Configurable<String> {
  late String id;
  DetailsModule();

  @override
  void configure(String args) {
    id = args;
  }

  @override
  List<Type> get expects => [AuthService];

  @override
  void binds(Binder i) {}
}

@RoutePage()
class DetailsPage extends StatelessWidget {
  final String id;
  const DetailsPage({required this.id});

  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: DetailsModule(),
      args: id, // <-- Configurable
      child: Scaffold(
        appBar: AppBar(title: Text('Details $id')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Details for Item $id'),
              const SizedBox(height: 20),
              const Text('AuthService is available here too!'),
            ],
          ),
        ),
      ),
    );
  }
}
