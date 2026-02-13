import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'src/riverpod_module.dart';

final _observer = RouteObserver<ModalRoute<dynamic>>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      observer: _observer,
      child: MaterialApp(
        title: 'Riverpod Example',
        navigatorObservers: [_observer],
        home: ModuleScope(module: CounterModule(), child: const CounterPage()),
      ),
    );
  }
}
