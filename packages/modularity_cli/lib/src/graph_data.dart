import 'recording_binder.dart';

/// Types of directed relationships between modules in the dependency graph.
///
/// Used by [ModuleEdge] to distinguish import edges from ownership edges.
enum ModuleEdgeType {
  /// The source module imports the target module.
  imports,

  /// The source module owns the target as a submodule.
  owns,
}

/// Represents a single module as a node in the dependency graph.
///
/// Contains the module's bindings snapshot (public/private dependencies,
/// expects, warnings) and serializes to JSON for consumption by graph
/// renderers.
///
/// See also:
/// - [ModuleEdge] for relationships between nodes.
/// - [ModuleGraphData] for the complete graph structure.
class ModuleNode {
  /// Create a graph node for a module.
  ModuleNode({
    required this.id,
    required this.name,
    required this.isRoot,
    required this.publicDependencies,
    required this.privateDependencies,
    required this.expects,
    required this.warnings,
  });

  /// Unique identifier derived from the module runtime type.
  final String id;

  /// Human-readable module name.
  final String name;

  /// Whether this node is the root of the module tree.
  final bool isRoot;

  /// Dependencies exported through the public scope.
  final List<DependencyRecord> publicDependencies;

  /// Dependencies registered in the private scope.
  final List<DependencyRecord> privateDependencies;

  /// Types the module expects from ancestor scopes.
  final List<Type> expects;

  /// Warnings emitted during analysis of this module.
  final List<String> warnings;

  /// Serialize this node to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isRoot': isRoot,
    'publicDependencies': publicDependencies
        .map(
          (DependencyRecord d) => {
            'type': d.type.toString(),
            'kind': d.kind.label,
          },
        )
        .toList(),
    'privateDependencies': privateDependencies
        .map(
          (DependencyRecord d) => {
            'type': d.type.toString(),
            'kind': d.kind.label,
          },
        )
        .toList(),
    'expects': expects.map((t) => t.toString()).toList(),
    'warnings': warnings,
  };
}

/// Represents a directed relationship between two modules in the graph.
///
/// Edges are typed as either [ModuleEdgeType.imports] (dashed) or
/// [ModuleEdgeType.owns] (solid) and serialize to JSON for rendering.
class ModuleEdge {
  /// Create an edge from [source] to [target] with the given [type].
  ModuleEdge({required this.source, required this.target, required this.type});

  /// Identifier of the origin module node.
  final String source;

  /// Identifier of the destination module node.
  final String target;

  /// Kind of relationship (import or ownership).
  final ModuleEdgeType type;

  /// Serialize this edge to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'source': source,
    'target': target,
    'type': type.name,
  };
}

/// Complete graph data structure containing all [ModuleNode]s and
/// [ModuleEdge]s.
///
/// Produced by [GraphVisualizer.buildGraphData] and consumed by graph
/// renderers (e.g. [G6HtmlGenerator]) to produce interactive visualizations.
class ModuleGraphData {
  /// Create graph data from the given [nodes] and [edges].
  ModuleGraphData({required this.nodes, required this.edges});

  /// All module nodes in the graph.
  final List<ModuleNode> nodes;

  /// All directed edges between module nodes.
  final List<ModuleEdge> edges;

  /// Serialize the full graph to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
  };
}
