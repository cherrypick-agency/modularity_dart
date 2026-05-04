/// Core implementation of the Modularity dependency-injection framework.
///
/// Re-exports everything from `modularity_contracts` and adds:
/// - [SimpleBinder] / [SimpleBinderFactory] — pure-Dart DI container.
/// - [ModuleController] — module lifecycle engine.
/// - [ModuleOverrideScope] — hierarchical dependency overrides.
/// - `GraphResolver` / [ModuleRegistryKey] — import graph resolution.
/// - [ConsoleLogger] — default logger via `dart:developer`.
///
/// ```dart
/// import 'package:modularity_core/modularity_core.dart';
///
/// final controller = ModuleController(AppModule());
/// await controller.initialize({});
/// ```
library modularity_core;

export 'package:modularity_contracts/modularity_contracts.dart';

export 'src/di/simple_binder.dart';
export 'src/di/simple_binder_factory.dart';
export 'src/engine/module_controller.dart';
export 'src/engine/module_override_scope.dart';
export 'src/graph/module_graph_node_key.dart';
export 'src/graph/module_registry_key.dart';
export 'src/logger/console_logger.dart';
