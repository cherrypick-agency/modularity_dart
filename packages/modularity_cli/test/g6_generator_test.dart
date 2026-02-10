import 'package:modularity_cli/modularity_cli.dart';
import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:test/test.dart';

class _PrivateService {}

class PublicService {}

class FeatureModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<_PrivateService>(() => _PrivateService());
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<PublicService>(() => PublicService());
  }
}

class RootModule extends Module {
  @override
  List<Module> get imports => [FeatureModule()];

  @override
  void binds(Binder i) {}
}

void main() {
  group('GraphVisualizer G6', () {
    test('buildGraphData creates correct structure', () {
      final data = GraphVisualizer.buildGraphData(RootModule());

      expect(data.nodes, hasLength(2));
      expect(data.edges, hasLength(1));

      final rootNode = data.nodes.firstWhere((n) => n.name == 'RootModule');
      expect(rootNode.isRoot, isTrue);

      final featureNode = data.nodes.firstWhere(
        (n) => n.name == 'FeatureModule',
      );
      expect(featureNode.isRoot, isFalse);
      expect(featureNode.publicDependencies, hasLength(1));
      expect(featureNode.privateDependencies, hasLength(1));

      final edge = data.edges.first;
      expect(edge.source, equals('RootModule'));
      expect(edge.target, equals('FeatureModule'));
      expect(edge.type, equals(ModuleEdgeType.imports));
    });

    test('toJson produces valid structure', () {
      final data = GraphVisualizer.buildGraphData(RootModule());
      final json = data.toJson();

      expect(json['nodes'], isList);
      expect(json['edges'], isList);

      final nodes = json['nodes'] as List;
      expect(nodes.first['id'], isA<String>());
      expect(nodes.first['name'], isA<String>());
      expect(nodes.first['isRoot'], isA<bool>());
      expect(nodes.first['publicDependencies'], isList);
      expect(nodes.first['privateDependencies'], isList);

      final edges = json['edges'] as List;
      expect(edges.first['source'], isA<String>());
      expect(edges.first['target'], isA<String>());
      expect(edges.first['type'], isA<String>());
    });
  });
}
