import 'package:modularity_contracts/modularity_contracts.dart';
import 'html_generator.dart';
import 'browser_opener.dart';
import 'package:meta/meta.dart';

class GraphVisualizer {
  /// Generates a dependency graph for the given [rootModule] and opens it in the browser.
  static Future<void> visualize(Module rootModule) async {
    final dotContent = generateDot(rootModule);
    final htmlContent = HtmlGenerator.generate(dotContent);
    await BrowserOpener.openHtml(htmlContent);
  }

  @visibleForTesting
  static String generateDot(Module rootModule) {
    final buffer = StringBuffer();
    buffer.writeln('digraph Modules {');
    // Global settings
    buffer.writeln(
        '  node [shape=box, style="filled,rounded", fillcolor="#e3f2fd", fontname="Arial", penwidth=1.5, color="#90caf9"];');
    buffer.writeln('  edge [fontname="Arial", fontsize=10];');
    buffer.writeln('  rankdir=TB;'); // Top to Bottom layout

    final visited = <Type>{};
    final queue = [rootModule];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentType = current.runtimeType;

      if (visited.contains(currentType)) continue;
      visited.add(currentType);

      // Highlight root node
      if (current == rootModule) {
        buffer.writeln(
            '  "$currentType" [fillcolor="#bbdefb", color="#1565c0", penwidth=2.5];');
      }

      // 1. Imports (Dependencies) - Dashed arrows
      for (final imported in current.imports) {
        final importedType = imported.runtimeType;
        buffer.writeln(
            '  "$currentType" -> "$importedType" [style=dashed, color="#616161", label="imports"];');
        queue.add(imported);
      }

      // 2. Submodules (Composition) - Solid arrows with Diamond tail
      try {
        for (final submodule in current.submodules) {
          final submoduleType = submodule.runtimeType;
          // dir=back because diamond is at the tail (parent)
          // arrowtail=diamond represents "Composition"
          buffer.writeln(
              '  "$currentType" -> "$submoduleType" [dir=back, arrowtail=diamond, color="#1565c0", penwidth=1.5, label="owns"];');
          queue.add(submodule);
        }
      } catch (e) {
        // Handle potential errors if submodules fail to instantiate (e.g. bad constructor)
        print('Warning: Failed to read submodules of $currentType: $e');
      }
    }

    buffer.writeln('}');
    return buffer.toString();
  }
}
