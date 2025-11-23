import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'src/counter_module.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      child: MaterialApp(
        title: 'Bloc Example',
        navigatorObservers: [Modularity.observer],
        home: ModuleScope(
          module: CounterModule(),
          child: const CounterPage(),
        ),
      ),
    );
  }
}

