import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'src/riverpod_module.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      child: MaterialApp(
        title: 'Riverpod Example',
        navigatorObservers: [Modularity.observer],
        home: ModuleScope(
          module: CounterModule(),
          child: const CounterPage(),
        ),
      ),
    );
  }
}

