import 'package:flutter/widgets.dart';
import 'package:modularity_core/modularity_core.dart';

import '../retention/module_retainer.dart';

/// Root inherited widget for the Modularity framework.
///
/// Provides DI configuration, a shared [ModuleRetainer], and a global module
/// registry to the entire widget subtree. Must be placed above all
/// [ModuleScope] widgets in the tree.
///
/// ## Usage
///
/// ```dart
/// ModularityRoot(
///   binderFactory: SimpleBinderFactory(),
///   defaultLoadingBuilder: (_) => const CircularProgressIndicator(),
///   defaultErrorBuilder: (_, error, retry) => ErrorWidget(error),
///   child: MaterialApp(
///     navigatorObservers: [Modularity.observer],
///     home: const HomePage(),
///   ),
/// )
/// ```
///
/// See also:
/// - [ModuleScope] which uses the configuration provided by this widget.
/// - [Modularity] for global observer, interceptors, and lifecycle logging.
class ModularityRoot extends InheritedWidget {
  /// Create the root inherited widget that provides DI configuration and a
  /// shared [ModuleRetainer] to the widget subtree.
  ModularityRoot({
    super.key,
    required super.child,
    BinderFactory? binderFactory,
    this.defaultLoadingBuilder,
    this.defaultErrorBuilder,
    ModuleRetainer? retainer,
  }) : binderFactory = binderFactory ?? SimpleBinderFactory(),
       retainer = retainer ?? ModuleRetainer();
  final Map<ModuleRegistryKey, ModuleController> _registry = {};

  /// Factory used to create [Binder] instances for each [ModuleScope].
  ///
  /// Defaults to [SimpleBinderFactory] when not provided.
  final BinderFactory binderFactory;

  /// Optional builder for the default loading widget shown by [ModuleScope]
  /// while a module is initializing.
  final WidgetBuilder? defaultLoadingBuilder;

  /// Optional builder for the default error widget shown by [ModuleScope]
  /// when module initialization fails.
  final Widget Function(BuildContext, Object? error, VoidCallback retry)?
  defaultErrorBuilder;

  /// Shared [ModuleRetainer] that caches [ModuleController] instances across
  /// scopes using the [ModuleRetentionPolicy.keepAlive] policy.
  final ModuleRetainer retainer;

  @override
  bool updateShouldNotify(ModularityRoot oldWidget) =>
      binderFactory != oldWidget.binderFactory ||
      defaultLoadingBuilder != oldWidget.defaultLoadingBuilder ||
      defaultErrorBuilder != oldWidget.defaultErrorBuilder ||
      retainer != oldWidget.retainer;

  /// Return the nearest [ModularityRoot] ancestor, or throw a
  /// [ModuleConfigurationException] if none exists.
  static ModularityRoot of(BuildContext context) {
    final root = context.dependOnInheritedWidgetOfExactType<ModularityRoot>();
    if (root == null) {
      throw ModuleConfigurationException(
        'ModularityRoot not found. Please wrap your app in ModularityRoot (or ModularApp).',
      );
    }
    return root;
  }

  /// Return the global module registry from the nearest [ModularityRoot].
  static Map<ModuleRegistryKey, ModuleController> registryOf(
    BuildContext context,
  ) => of(context)._registry;

  /// Return the [BinderFactory] from the nearest [ModularityRoot].
  static BinderFactory binderFactoryOf(BuildContext context) =>
      of(context).binderFactory;

  /// Return the default loading builder from the nearest [ModularityRoot],
  /// or `null` if none was configured.
  static WidgetBuilder? defaultLoadingBuilderOf(BuildContext context) =>
      of(context).defaultLoadingBuilder;

  /// Return the default error builder from the nearest [ModularityRoot],
  /// or `null` if none was configured.
  static Widget Function(BuildContext, Object?, VoidCallback)?
  defaultErrorBuilderOf(BuildContext context) =>
      of(context).defaultErrorBuilder;

  /// Return the shared [ModuleRetainer] from the nearest [ModularityRoot].
  static ModuleRetainer retainerOf(BuildContext context) =>
      of(context).retainer;
}
