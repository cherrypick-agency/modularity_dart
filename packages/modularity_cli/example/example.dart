import 'package:modularity_cli/modularity_cli.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

class AuthService {}

class AuthRepository {}

class AuthModule extends Module {
  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<AuthRepository>(() => AuthRepository());
  }

  @override
  void exports(Binder binder) {
    binder.registerLazySingleton<AuthService>(() => AuthService());
  }
}

class HomeModule extends Module {
  @override
  List<Module> get imports => [AuthModule()];

  @override
  void binds(Binder binder) {}
}

class MyRootModule extends Module {
  @override
  List<Module> get submodules => [HomeModule()];

  @override
  void binds(Binder binder) {}
}

void main() async {
  print('Generating graph for MyRootModule...');

  try {
    // Option 1: Static Graphviz diagram (default)
    print('\n--- Graphviz (static) ---');
    await GraphVisualizer.visualize(MyRootModule());

    // Option 2: Interactive AntV G6 diagram
    print('\n--- AntV G6 (interactive) ---');
    await GraphVisualizer.visualize(MyRootModule(), renderer: GraphRenderer.g6);

    print('Graphs generated successfully.');
  } catch (e) {
    print('Error generating graph: $e');
  }
}
