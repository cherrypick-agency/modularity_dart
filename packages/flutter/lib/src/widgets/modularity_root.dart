import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:modularity_core/modularity_core.dart';

import '../retention/module_retainer.dart';

/// Lifecycle event types emitted by the retention and scope systems.
///
/// Used with [ModuleLifecycleLogger] to trace module creation, reuse,
/// caching, and disposal.
enum ModuleLifecycleEvent {
  /// Controller created for the first time.
  created,

  /// Existing controller reused from cache.
  reused,

  /// Controller registered in retention cache.
  registered,

  /// Controller disposed.
  disposed,

  /// Controller evicted from retention cache.
  evicted,

  /// Controller released (ref count decremented).
  released,

  /// Route termination triggered controller cleanup.
  routeTerminated,
}

/// Callback signature for module lifecycle logging.
///
/// Parameters:
/// - [event]: The lifecycle event type.
/// - [moduleType]: The runtime type of the module.
/// - [retentionKey]: The cache key (null if not applicable).
/// - [details]: Additional context (override scope hash, ref count, etc.).
typedef ModuleLifecycleLogger =
    void Function(
      ModuleLifecycleEvent event,
      Type moduleType, {
      Object? retentionKey,
      Map<String, Object?>? details,
    });

void _defaultDebugLogger(
  ModuleLifecycleEvent event,
  Type moduleType, {
  Object? retentionKey,
  Map<String, Object?>? details,
}) {
  final buffer = StringBuffer()
    ..write('[Modularity] ')
    ..write(event.name.toUpperCase())
    ..write(' ')
    ..write(moduleType);

  if (retentionKey != null) {
    buffer
      ..write(' key=')
      ..write(retentionKey);
  }

  if (details != null && details.isNotEmpty) {
    buffer
      ..write(' ')
      ..write(details);
  }

  debugPrint(buffer.toString());
}

/// Root widget for the Modularity framework.
///
/// Provides DI configuration, a shared [ModuleRetainer], a global module
/// registry, and lifecycle management to the entire widget subtree. Must be
/// placed above all [ModuleScope] widgets in the tree.
///
/// ## Usage
///
/// ```dart
/// final observer = RouteObserver<ModalRoute<dynamic>>();
///
/// ModularityRoot(
///   observer: observer,
///   interceptors: [TimingInterceptor()],
///   lifecycleLogger: kDebugMode ? ModularityRoot.defaultDebugLogger : null,
///   child: MaterialApp(
///     navigatorObservers: [observer],
///     home: const HomePage(),
///   ),
/// )
/// ```
///
/// See also:
/// - [ModuleScope] which uses the configuration provided by this widget.
class ModularityRoot extends StatefulWidget {
  /// Create the root widget that provides DI configuration and a
  /// shared [ModuleRetainer] to the widget subtree.
  const ModularityRoot({
    super.key,
    required this.child,
    this.binderFactory,
    this.defaultLoadingBuilder,
    this.defaultErrorBuilder,
    this.observer,
    this.interceptors,
    this.lifecycleLogger,
    this.retainer,
  });

  /// Widget subtree that receives the modularity configuration.
  final Widget child;

  /// Factory used to create [Binder] instances for each [ModuleScope].
  ///
  /// Defaults to [SimpleBinderFactory] when not provided.
  final BinderFactory? binderFactory;

  /// Optional builder for the default loading widget shown by [ModuleScope]
  /// while a module is initializing.
  final WidgetBuilder? defaultLoadingBuilder;

  /// Optional builder for the default error widget shown by [ModuleScope]
  /// when module initialization fails.
  final Widget Function(BuildContext, Object? error, VoidCallback retry)?
  defaultErrorBuilder;

  /// [RouteObserver] for route-bound and keep-alive retention policies.
  ///
  /// When provided, pass the same observer to
  /// `MaterialApp.navigatorObservers` so that route lifecycle events are
  /// forwarded to the framework.
  ///
  /// When omitted, a default observer is created internally with a debug
  /// warning that route-bound retention will not work unless the observer is
  /// also registered in the navigator.
  final RouteObserver<ModalRoute<dynamic>>? observer;

  /// Global list of [ModuleInterceptor]s applied to all modules.
  final List<ModuleInterceptor>? interceptors;

  /// Optional logger for module lifecycle events.
  ///
  /// When set, receives callbacks for module creation/reuse, retention
  /// cache register/release/evict, and route termination handling.
  final ModuleLifecycleLogger? lifecycleLogger;

  /// Shared [ModuleRetainer] that caches [ModuleController] instances across
  /// scopes using the [ModuleRetentionPolicy.keepAlive] policy.
  final ModuleRetainer? retainer;

  /// Default debug logger that prints lifecycle events via [debugPrint].
  static const ModuleLifecycleLogger defaultDebugLogger = _defaultDebugLogger;

  /// Return the [RouteObserver] from the nearest [ModularityRoot].
  static RouteObserver<ModalRoute<dynamic>> observerOf(BuildContext context) =>
      _of(context).observer;

  /// Return the [BinderFactory] from the nearest [ModularityRoot].
  static BinderFactory binderFactoryOf(BuildContext context) =>
      _of(context).binderFactory;

  /// Return the global module registry from the nearest [ModularityRoot].
  static Map<ModuleRegistryKey, ModuleController> registryOf(
    BuildContext context,
  ) => _of(context).registry;

  /// Return the shared [ModuleRetainer] from the nearest [ModularityRoot].
  static ModuleRetainer retainerOf(BuildContext context) =>
      _of(context).retainer;

  /// Return the list of [ModuleInterceptor]s from the nearest
  /// [ModularityRoot].
  static List<ModuleInterceptor> interceptorsOf(BuildContext context) =>
      _of(context).interceptors;

  /// Return the default loading builder from the nearest [ModularityRoot],
  /// or `null` if none was configured.
  static WidgetBuilder? defaultLoadingBuilderOf(BuildContext context) =>
      _of(context).defaultLoadingBuilder;

  /// Return the default error builder from the nearest [ModularityRoot],
  /// or `null` if none was configured.
  static Widget Function(BuildContext, Object?, VoidCallback)?
  defaultErrorBuilderOf(BuildContext context) =>
      _of(context).defaultErrorBuilder;

  /// Log a lifecycle event via the logger from the nearest [ModularityRoot].
  ///
  /// Does nothing if no [lifecycleLogger] is configured.
  static void log(
    BuildContext context,
    ModuleLifecycleEvent event,
    Type moduleType, {
    Object? retentionKey,
    Map<String, Object?>? details,
  }) {
    _of(context).lifecycleLogger?.call(
      event,
      moduleType,
      retentionKey: retentionKey,
      details: details,
    );
  }

  static _InheritedModularity _of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedModularity>();
    if (scope == null) {
      throw ModuleConfigurationException(
        'ModularityRoot not found. Wrap your app in ModularityRoot.',
      );
    }
    return scope;
  }

  @override
  State<ModularityRoot> createState() => _ModularityRootState();
}

class _ModularityRootState extends State<ModularityRoot> {
  late final BinderFactory _binderFactory;
  late final RouteObserver<ModalRoute<dynamic>> _observer;
  late final List<ModuleInterceptor> _interceptors;
  late final ModuleRetainer _retainer;
  final Map<ModuleRegistryKey, ModuleController> _registry = {};

  @override
  void initState() {
    super.initState();
    _binderFactory = widget.binderFactory ?? SimpleBinderFactory();
    _observer = widget.observer ?? RouteObserver<ModalRoute<dynamic>>();
    _interceptors = List.unmodifiable(widget.interceptors ?? const []);
    _retainer = widget.retainer ?? ModuleRetainer();
    _retainer.logger = widget.lifecycleLogger;

    assert(() {
      if (widget.observer == null) {
        debugPrint(
          '[ModularityRoot] No observer provided. RouteBound and '
          'KeepAlive retention policies require the observer to be '
          'registered in MaterialApp.navigatorObservers. '
          'Pass an explicit observer to ModularityRoot.',
        );
      }
      return true;
    }());
  }

  @override
  void didUpdateWidget(ModularityRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.lifecycleLogger, oldWidget.lifecycleLogger)) {
      _retainer.logger = widget.lifecycleLogger;
    }
    _reportIfChanged(
      oldWidget.binderFactory,
      widget.binderFactory,
      'binderFactory',
    );
    _reportIfChanged(oldWidget.observer, widget.observer, 'observer');
    _reportIfChanged(oldWidget.retainer, widget.retainer, 'retainer');
    _reportIfChanged(
      oldWidget.interceptors,
      widget.interceptors,
      'interceptors',
    );
  }

  void _reportIfChanged(Object? oldValue, Object? newValue, String field) {
    if (!identical(oldValue, newValue)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError.fromParts([
            ErrorSummary('ModularityRoot.$field must not change.'),
            ErrorHint('Use a different Key to force a new ModularityRoot.'),
          ]),
          library: 'modularity_flutter',
        ),
      );
    }
  }

  @override
  void dispose() {
    _retainer.logger = null;
    final controllers = _registry.values.toSet().toList(growable: false);
    assert(() {
      if (controllers.isNotEmpty) {
        debugPrint(
          '[ModularityRoot] ${controllers.length} controllers still in '
          'registry at root disposal.',
        );
      }
      return true;
    }());
    _registry.clear();
    if (controllers.isNotEmpty) {
      unawaited(_disposeRegistryControllers(controllers));
    }
    super.dispose();
  }

  Future<void> _disposeRegistryControllers(
    List<ModuleController> controllers,
  ) async {
    try {
      await Future.wait<void>(
        controllers.map((controller) => controller.dispose()),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'modularity_flutter',
          context: ErrorDescription('while disposing ModularityRoot registry'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedModularity(
      binderFactory: _binderFactory,
      observer: _observer,
      interceptors: _interceptors,
      lifecycleLogger: widget.lifecycleLogger,
      defaultLoadingBuilder: widget.defaultLoadingBuilder,
      defaultErrorBuilder: widget.defaultErrorBuilder,
      retainer: _retainer,
      registry: _registry,
      child: widget.child,
    );
  }
}

class _InheritedModularity extends InheritedWidget {
  const _InheritedModularity({
    required this.binderFactory,
    required this.observer,
    required this.interceptors,
    this.lifecycleLogger,
    this.defaultLoadingBuilder,
    this.defaultErrorBuilder,
    required this.retainer,
    required this.registry,
    required super.child,
  });

  final BinderFactory binderFactory;
  final RouteObserver<ModalRoute<dynamic>> observer;
  final List<ModuleInterceptor> interceptors;
  final ModuleLifecycleLogger? lifecycleLogger;
  final WidgetBuilder? defaultLoadingBuilder;
  final Widget Function(BuildContext, Object?, VoidCallback)?
  defaultErrorBuilder;
  final ModuleRetainer retainer;
  final Map<ModuleRegistryKey, ModuleController> registry;

  @override
  bool updateShouldNotify(_InheritedModularity oldWidget) =>
      binderFactory != oldWidget.binderFactory ||
      observer != oldWidget.observer ||
      defaultLoadingBuilder != oldWidget.defaultLoadingBuilder ||
      defaultErrorBuilder != oldWidget.defaultErrorBuilder ||
      retainer != oldWidget.retainer;
}
