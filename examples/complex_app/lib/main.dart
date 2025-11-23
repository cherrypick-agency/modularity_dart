import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'modules/home/home_module.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      child: MaterialApp(
        title: 'Complex Modularity App',
        navigatorObservers: [Modularity.observer], // Enable RouteBound retention
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: ModuleScope(
          module: HomeModule(),
          child: const HomePage(),
        ),
      ),
    );
  }
}

