import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

void main() {
  runApp(ModularityRoot(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomeModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton(() => 'Hello from Home Module!');
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: HomeModule(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Modularity Example')),
        body: Center(
          child: Builder(
            builder: (context) {
              // Access dependency from the current module scope
              // We use ModuleProvider.of(context) to get the binder
              final binder = ModuleProvider.of(context);
              final message = binder.get<String>();
              return Text(message);
            },
          ),
        ),
      ),
    );
  }
}
