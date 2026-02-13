/// CLI tools for analyzing and visualizing Modularity module dependency graphs.
///
/// Provides utilities to introspect a module tree at build time and render the
/// resulting dependency graph in a browser.
///
/// ## Key Classes
///
/// - [GraphVisualizer] -- generates and opens dependency graph visualizations.
/// - [ModuleGraphData], [ModuleNode], [ModuleEdge] -- structured graph data.
/// - [DependencyRecord] -- metadata about a single DI registration.
/// - [DependencyRegistrationKind] -- registration strategy (singleton/factory/instance).
///
/// ## Quick Start
///
/// ```dart
/// import 'package:modularity_cli/modularity_cli.dart';
///
/// void main() async {
///   await GraphVisualizer.visualize(
///     AppModule(),
///     renderer: GraphRenderer.g6,
///   );
/// }
/// ```
library modularity_cli;

export 'src/graph_data.dart';
export 'src/graph_visualizer.dart';
export 'src/module_bindings_analyzer.dart';
export 'src/recording_binder.dart';
