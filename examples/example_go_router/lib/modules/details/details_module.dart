import 'package:flutter/material.dart';
import 'package:modularity_contracts/modularity_contracts.dart'; // Configurable
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
  void binds(Binder i) {
    // We can bind something specific to this detail using the id
  }
}

class DetailsPage extends StatelessWidget {
  final String id;
  const DetailsPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
