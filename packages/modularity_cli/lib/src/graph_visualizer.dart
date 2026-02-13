import 'package:modularity_contracts/modularity_contracts.dart';

import 'browser_opener.dart';
import 'g6_html_generator.dart';
import 'graph_data.dart';
import 'html_generator.dart';
import 'module_bindings_analyzer.dart';

/// Available visualization renderers.
enum GraphRenderer {
  /// Static Graphviz DOT diagram rendered via quickchart.io.
  graphviz,

  /// Interactive AntV G6 diagram with drag, zoom, and tooltips.
  g6,
}

/// Generate and display module dependency graphs in a browser.
///
/// Supports both static Graphviz DOT diagrams and interactive AntV G6
/// visualizations through the [GraphRenderer] selection.
///
/// ## Usage
///
/// ```dart
/// // Interactive G6 visualization
/// await GraphVisualizer.visualize(AppModule(), renderer: GraphRenderer.g6);
///
/// // Static Graphviz DOT diagram
/// await GraphVisualizer.visualize(AppModule());
/// ```
///
/// See also:
/// - [GraphRenderer] for available rendering backends.
/// - [ModuleBindingsAnalyzer] for the underlying analysis.
class GraphVisualizer {
  /// Generates a dependency graph for the given [rootModule] and opens it in the browser.
  ///
  /// [renderer] controls which visualization library to use:
  /// - [GraphRenderer.graphviz] (default): Static DOT diagram via quickchart.io
  /// - [GraphRenderer.g6]: Interactive AntV G6 diagram with tooltips
  static Future<void> visualize(
    Module rootModule, {
    GraphRenderer renderer = GraphRenderer.graphviz,
  }) async {
    final String htmlContent;

    switch (renderer) {
      case GraphRenderer.graphviz:
        final dotContent = generateDot(rootModule);
        htmlContent = HtmlGenerator.generate(dotContent);
        break;
      case GraphRenderer.g6:
        final graphData = buildGraphData(rootModule);
        htmlContent = G6HtmlGenerator.generate(graphData);
        break;
    }

    await BrowserOpener.openHtml(htmlContent);
  }

  /// Builds structured graph data from module tree.
  ///
  /// Useful for CI pipelines and programmatic access to the dependency graph
  /// without rendering it in a browser.
  static ModuleGraphData buildGraphData(Module rootModule) {
    final nodes = <ModuleNode>[];
    final edges = <ModuleEdge>[];
    final visited = <Type>{};
    final queue = [rootModule];
    final analyzer = ModuleBindingsAnalyzer();

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentType = current.runtimeType;

      if (visited.contains(currentType)) continue;
      visited.add(currentType);

      final snapshot = analyzer.analyze(current);
      final nodeId = currentType.toString();

      nodes.add(
        ModuleNode(
          id: nodeId,
          name: currentType.toString(),
          isRoot: current == rootModule,
          publicDependencies: snapshot.publicDependencies,
          privateDependencies: snapshot.privateDependencies,
          expects: snapshot.expects,
          warnings: snapshot.warnings,
        ),
      );

      for (final imported in current.imports) {
        final importedType = imported.runtimeType;
        edges.add(
          ModuleEdge(
            source: nodeId,
            target: importedType.toString(),
            type: ModuleEdgeType.imports,
          ),
        );
        queue.add(imported);
      }

      try {
        for (final submodule in current.submodules) {
          final submoduleType = submodule.runtimeType;
          edges.add(
            ModuleEdge(
              source: nodeId,
              target: submoduleType.toString(),
              type: ModuleEdgeType.owns,
            ),
          );
          queue.add(submodule);
        }
      } catch (e) {
        print('Warning: Failed to read submodules of $currentType: $e');
      }
    }

    return ModuleGraphData(nodes: nodes, edges: edges);
  }

  /// Generate a Graphviz DOT string representing the module tree of [rootModule].
  ///
  /// Returns a DOT-format string suitable for rendering with Graphviz or
  /// embedding in CI reports.
  static String generateDot(Module rootModule) {
    final buffer = StringBuffer()
      ..writeln('digraph Modules {')
      ..writeln(
        '  node [shape=box, style="filled,rounded", fillcolor="#e3f2fd", fontname="Arial", penwidth=1.5, color="#90caf9"];',
      )
      ..writeln('  edge [fontname="Arial", fontsize=10];')
      ..writeln('  rankdir=TB;');

    final visited = <Type>{};
    final queue = [rootModule];
    final analyzer = ModuleBindingsAnalyzer();

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentType = current.runtimeType;

      if (visited.contains(currentType)) continue;
      visited.add(currentType);

      final snapshot = analyzer.analyze(current);
      final attributes = <String>['label=${_buildNodeLabel(snapshot)}'];

      if (current == rootModule) {
        attributes
          ..add('fillcolor="#bbdefb"')
          ..add('color="#1565c0"')
          ..add('penwidth=2.5');
      }

      buffer.writeln('  "$currentType" [${attributes.join(', ')}];');

      for (final imported in current.imports) {
        final importedType = imported.runtimeType;
        buffer.writeln(
          '  "$currentType" -> "$importedType" [style=dashed, color="#616161", label="imports"];',
        );
        queue.add(imported);
      }

      try {
        for (final submodule in current.submodules) {
          final submoduleType = submodule.runtimeType;
          buffer.writeln(
            '  "$currentType" -> "$submoduleType" [dir=back, arrowtail=diamond, color="#1565c0", penwidth=1.5, label="owns"];',
          );
          queue.add(submodule);
        }
      } catch (e) {
        print('Warning: Failed to read submodules of $currentType: $e');
      }
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  static String _buildNodeLabel(ModuleBindingsSnapshot snapshot) {
    final moduleName = _escapeHtml(snapshot.moduleType.toString());

    if (!snapshot.hasBindings &&
        !snapshot.hasExpects &&
        snapshot.warnings.isEmpty) {
      return '<B>$moduleName</B>';
    }

    final content = StringBuffer()
      ..writeln(
        '<TABLE BORDER="0" CELLBORDER="0" CELLPADDING="2" CELLSPACING="0">',
      )
      ..writeln('<TR><TD><B>$moduleName</B></TD></TR>');

    if (snapshot.publicDependencies.isNotEmpty) {
      content.writeln(
        '<TR><TD ALIGN="left"><FONT POINT-SIZE="10">Public</FONT></TD></TR>',
      );
      for (final dep in snapshot.publicDependencies) {
        content.writeln(
          '<TR><TD ALIGN="left"><FONT POINT-SIZE="9">- ${_escapeHtml(dep.displayName)}</FONT></TD></TR>',
        );
      }
    }

    if (snapshot.privateDependencies.isNotEmpty) {
      content.writeln(
        '<TR><TD ALIGN="left"><FONT POINT-SIZE="10">Private</FONT></TD></TR>',
      );
      for (final dep in snapshot.privateDependencies) {
        content.writeln(
          '<TR><TD ALIGN="left"><FONT POINT-SIZE="9">- ${_escapeHtml(dep.displayName)}</FONT></TD></TR>',
        );
      }
    }

    if (snapshot.expects.isNotEmpty) {
      content.writeln(
        '<TR><TD ALIGN="left"><FONT POINT-SIZE="10" COLOR="#ff8f00">Expects</FONT></TD></TR>',
      );
      for (final type in snapshot.expects) {
        content.writeln(
          '<TR><TD ALIGN="left"><FONT POINT-SIZE="9" COLOR="#ff8f00">- ${_escapeHtml(type.toString())}</FONT></TD></TR>',
        );
      }
    }

    if (snapshot.warnings.isNotEmpty) {
      content.writeln(
        '<TR><TD ALIGN="left"><FONT POINT-SIZE="8" COLOR="#c62828">Warnings during analysis (see console)</FONT></TD></TR>',
      );
    }

    content.writeln('</TABLE>');
    return '<${content.toString()}>';
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
