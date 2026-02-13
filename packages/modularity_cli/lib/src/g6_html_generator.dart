import 'dart:convert';
import 'graph_data.dart';

/// Generates an interactive HTML page using AntV G6 for graph visualization.
///
/// Produces a self-contained HTML document with drag, zoom, and tooltip
/// support. Nodes display module names; hovering shows dependency details.
///
/// See also:
/// - [HtmlGenerator] for static Graphviz rendering.
/// - [GraphVisualizer] which selects the appropriate generator.
class G6HtmlGenerator {
  /// Returns a self-contained HTML string visualizing [graphData] with an
  /// interactive AntV G6 diagram.
  static String generate(ModuleGraphData graphData) {
    final jsonData = jsonEncode(graphData.toJson());

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Modularity Graph - Interactive</title>
  <script src="https://unpkg.com/@antv/g6@5/dist/g6.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'SF Pro Display', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      min-height: 100vh;
      color: #e8e8e8;
    }
    .header {
      padding: 16px 24px;
      background: rgba(0, 0, 0, 0.3);
      backdrop-filter: blur(10px);
      border-bottom: 1px solid rgba(255, 255, 255, 0.1);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .header h1 {
      font-size: 20px;
      font-weight: 600;
      background: linear-gradient(90deg, #00d9ff, #00ff88);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    .controls {
      display: flex;
      gap: 12px;
      align-items: center;
    }
    .btn {
      padding: 8px 16px;
      border: 1px solid rgba(255, 255, 255, 0.2);
      background: rgba(255, 255, 255, 0.05);
      color: #e8e8e8;
      border-radius: 6px;
      cursor: pointer;
      font-size: 13px;
      transition: all 0.2s;
    }
    .btn:hover {
      background: rgba(255, 255, 255, 0.15);
      border-color: rgba(255, 255, 255, 0.3);
    }
    #container {
      width: 100%;
      height: calc(100vh - 60px);
    }
    .legend {
      position: fixed;
      bottom: 20px;
      left: 20px;
      background: rgba(0, 0, 0, 0.6);
      backdrop-filter: blur(10px);
      padding: 16px;
      border-radius: 12px;
      border: 1px solid rgba(255, 255, 255, 0.1);
      font-size: 12px;
    }
    .legend-item {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 8px;
    }
    .legend-item:last-child { margin-bottom: 0; }
    .legend-line {
      width: 30px;
      height: 2px;
    }
    .legend-line.imports {
      background: #ff6b6b;
      border-style: dashed;
    }
    .legend-line.owns {
      background: #4ecdc4;
    }
    .legend-node {
      width: 16px;
      height: 16px;
      border-radius: 4px;
    }
    .legend-node.root {
      background: linear-gradient(135deg, #00d9ff, #00ff88);
    }
    .legend-node.module {
      background: #4a5568;
      border: 2px solid #718096;
    }
    .tooltip {
      position: fixed;
      background: rgba(0, 0, 0, 0.9);
      backdrop-filter: blur(10px);
      padding: 16px;
      border-radius: 12px;
      border: 1px solid rgba(255, 255, 255, 0.2);
      max-width: 350px;
      font-size: 13px;
      pointer-events: none;
      opacity: 0;
      transition: opacity 0.2s;
      z-index: 1000;
    }
    .tooltip.visible { opacity: 1; }
    .tooltip h3 {
      font-size: 15px;
      margin-bottom: 12px;
      color: #00d9ff;
    }
    .tooltip-section {
      margin-bottom: 10px;
    }
    .tooltip-section:last-child { margin-bottom: 0; }
    .tooltip-section-title {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: #888;
      margin-bottom: 4px;
    }
    .tooltip-section-title.public { color: #00ff88; }
    .tooltip-section-title.private { color: #ff6b6b; }
    .tooltip-section-title.expects { color: #fbbf24; }
    .dep-item {
      padding: 2px 0;
      color: #ccc;
    }
    .dep-kind {
      color: #888;
      font-size: 11px;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>Modularity Dependency Graph</h1>
    <div class="controls">
      <button class="btn" onclick="fitView()">Fit View</button>
      <button class="btn" onclick="zoomIn()">Zoom In</button>
      <button class="btn" onclick="zoomOut()">Zoom Out</button>
    </div>
  </div>
  <div id="container"></div>
  <div class="legend">
    <div class="legend-item">
      <div class="legend-node root"></div>
      <span>Root Module</span>
    </div>
    <div class="legend-item">
      <div class="legend-node module"></div>
      <span>Module</span>
    </div>
    <div class="legend-item">
      <div class="legend-line imports" style="border-top: 2px dashed #ff6b6b; height: 0;"></div>
      <span>imports</span>
    </div>
    <div class="legend-item">
      <div class="legend-line owns"></div>
      <span>owns (submodule)</span>
    </div>
  </div>
  <div class="tooltip" id="tooltip"></div>

  <script>
    const graphData = $jsonData;
    let graph;

    const nodes = graphData.nodes.map(node => ({
      id: node.id,
      data: {
        name: node.name,
        isRoot: node.isRoot,
        publicDependencies: node.publicDependencies,
        privateDependencies: node.privateDependencies,
        warnings: node.warnings,
      },
    }));

    const edges = graphData.edges.map((edge, idx) => ({
      id: 'edge-' + idx,
      source: edge.source,
      target: edge.target,
      data: { type: edge.type },
    }));

    const container = document.getElementById('container');

    graph = new G6.Graph({
      container: 'container',
      width: container.offsetWidth,
      height: container.offsetHeight,
      data: { nodes, edges },
      autoFit: 'view',
      node: {
        type: 'rect',
        style: (d) => {
          const isRoot = d.data?.isRoot;
          const name = d.data?.name || d.id;
          const width = Math.max(140, name.length * 9 + 24);
          return {
            size: [width, 44],
            radius: 8,
            fill: isRoot ? 'l(45) 0:#00d9ff 1:#00ff88' : '#2d3748',
            stroke: isRoot ? '#00ff88' : '#4a5568',
            lineWidth: isRoot ? 2 : 1,
            shadowColor: isRoot ? 'rgba(0, 217, 255, 0.3)' : 'rgba(0,0,0,0.3)',
            shadowBlur: isRoot ? 20 : 10,
            shadowOffsetY: 4,
            labelText: name,
            labelFill: isRoot ? '#1a1a2e' : '#e8e8e8',
            labelFontSize: 13,
            labelFontWeight: isRoot ? 600 : 400,
            labelPlacement: 'center',
            labelMaxWidth: width - 16,
          };
        },
      },
      edge: {
        type: 'cubic-vertical',
        style: (d) => {
          const isImports = d.data?.type === 'imports';
          return {
            stroke: isImports ? '#ff6b6b' : '#4ecdc4',
            lineWidth: 2,
            lineDash: isImports ? [6, 4] : undefined,
            endArrow: true,
            endArrowSize: 8,
            endArrowFill: isImports ? '#ff6b6b' : '#4ecdc4',
          };
        },
      },
      layout: {
        type: 'dagre',
        rankdir: 'TB',
        nodesep: 60,
        ranksep: 80,
      },
      behaviors: ['drag-canvas', 'zoom-canvas', 'drag-element'],
    });

    graph.render();

    const tooltip = document.getElementById('tooltip');

    graph.on('node:pointerenter', (e) => {
      const nodeData = e.target.id;
      const node = graphData.nodes.find(n => n.id === nodeData);
      if (!node) return;

      let html = '<h3>' + node.name + '</h3>';

      if (node.publicDependencies.length > 0) {
        html += '<div class="tooltip-section">';
        html += '<div class="tooltip-section-title public">Public Exports</div>';
        node.publicDependencies.forEach(dep => {
          html += '<div class="dep-item">' + dep.type + ' <span class="dep-kind">[' + dep.kind + ']</span></div>';
        });
        html += '</div>';
      }

      if (node.privateDependencies.length > 0) {
        html += '<div class="tooltip-section">';
        html += '<div class="tooltip-section-title private">Private Bindings</div>';
        node.privateDependencies.forEach(dep => {
          html += '<div class="dep-item">' + dep.type + ' <span class="dep-kind">[' + dep.kind + ']</span></div>';
        });
        html += '</div>';
      }

      if (node.expects && node.expects.length > 0) {
        html += '<div class="tooltip-section">';
        html += '<div class="tooltip-section-title expects">Expects (from parent)</div>';
        node.expects.forEach(type => {
          html += '<div class="dep-item">' + type + '</div>';
        });
        html += '</div>';
      }

      if (node.warnings.length > 0) {
        html += '<div class="tooltip-section">';
        html += '<div class="tooltip-section-title" style="color: #f59e0b;">Warnings</div>';
        node.warnings.forEach(w => {
          html += '<div class="dep-item" style="color: #f59e0b;">' + w + '</div>';
        });
        html += '</div>';
      }

      if (node.publicDependencies.length === 0 && node.privateDependencies.length === 0 && (!node.expects || node.expects.length === 0)) {
        html += '<div class="tooltip-section"><div class="dep-item" style="color: #888;">No bindings registered</div></div>';
      }

      tooltip.innerHTML = html;
      tooltip.classList.add('visible');
    });

    graph.on('node:pointermove', (e) => {
      const event = e.nativeEvent || e;
      tooltip.style.left = (event.clientX + 15) + 'px';
      tooltip.style.top = (event.clientY + 15) + 'px';
    });

    graph.on('node:pointerleave', () => {
      tooltip.classList.remove('visible');
    });

    function fitView() {
      graph.fitView();
    }

    function zoomIn() {
      graph.zoomTo(graph.getZoom() * 1.2);
    }

    function zoomOut() {
      graph.zoomTo(graph.getZoom() / 1.2);
    }

    window.addEventListener('resize', () => {
      graph.setSize(container.offsetWidth, container.offsetHeight);
    });
  </script>
</body>
</html>
''';
  }
}
