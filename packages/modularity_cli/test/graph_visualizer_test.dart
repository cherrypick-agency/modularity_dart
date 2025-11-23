import 'package:modularity_cli/modularity_cli.dart';
// ignore: depend_on_referenced_packages
import 'package:modularity_cli/src/graph_visualizer.dart'; // Access to internal for testing
import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:test/test.dart';

// --- Test Modules ---
class RootModule extends Module {
  @override
  List<Module> get imports => [FeatureModule()];
  
  @override
  List<Module> get submodules => [NestedModule()];

  @override
  void binds(Binder i) {}
}

class FeatureModule extends Module {
  @override
  void binds(Binder i) {}
}

class NestedModule extends Module {
  @override
  void binds(Binder i) {}
}

void main() {
  group('GraphVisualizer', () {
    test('generateDot produces valid DOT format', () {
      final dot = GraphVisualizer.generateDot(RootModule());
      
      print(dot);

      expect(dot, contains('digraph Modules {'));
      // Root node highlighted
      expect(dot, contains('"RootModule" [fillcolor="#bbdefb", color="#1565c0", penwidth=2.5];'));
      
      // Import arrow
      expect(dot, contains('"RootModule" -> "FeatureModule" [style=dashed, color="#616161", label="imports"];'));
      
      // Submodule composition arrow
      expect(dot, contains('"RootModule" -> "NestedModule" [dir=back, arrowtail=diamond, color="#1565c0", penwidth=1.5, label="owns"];'));
    });
  });
}
