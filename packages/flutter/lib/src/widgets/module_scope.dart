import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:modularity_core/modularity_core.dart';

import '../modularity.dart';
import '../retention/module_retention_strategy.dart';
import '../retention/retention_identity.dart';
import 'modularity_root.dart';
import 'module_provider.dart';

/// Widget that manages the lifecycle of a [Module] and exposes its DI container.
///
/// [ModuleScope] creates a [ModuleController], initializes the module, and
/// provides the resulting [Binder] to descendants via [ModuleProvider]. It
/// handles loading and error states and supports configurable retention
/// policies that control when the controller is disposed or reused.
///
/// ## Basic Usage
///
/// ```dart
/// ModuleScope<AuthModule>(
///   module: AuthModule(),
///   child: const AuthPage(),
/// )
/// ```
///
/// ## Retention Policy
///
/// Controls how the [ModuleController] is retained across widget rebuilds:
///
/// - [ModuleRetentionPolicy.strict] -- controller disposed on every unmount.
/// - [ModuleRetentionPolicy.routeBound] -- controller disposed when route pops.
/// - [ModuleRetentionPolicy.keepAlive] -- controller cached in [ModuleRetainer],
///   survives widget unmount, disposed on route termination or explicit eviction.
///
/// ## Retention Key vs Override Scope
///
/// **Important distinction**:
///
/// - [retentionKey] determines cache identity for KeepAlive policy.
/// - [overrideScope] affects DI bindings but NOT cache identity.
///
/// Two scopes with the same [retentionKey] but different [overrideScope]s will
/// **share** the same cached controller (first scope's overrides win).
///
/// To make overrides affect caching, include scope identity in the key:
///
/// ```dart
/// ModuleScope(
///   module: MyModule(),
///   retentionPolicy: ModuleRetentionPolicy.keepAlive,
///   retentionKey: 'my-module-${identityHashCode(overrideScope)}',
///   overrideScope: overrideScope,
///   child: ...,
/// )
/// ```
///
/// See also:
/// - [ModuleProvider] for accessing the module's [Binder] from descendants.
/// - [ModularityRoot] for top-level DI configuration.
class ModuleScope<T extends Module> extends StatefulWidget {
  /// Create a [ModuleScope] that manages the lifecycle of [module].
  const ModuleScope({
    super.key,
    required this.module,
    required this.child,
    this.args,
    this.loadingBuilder,
    this.errorBuilder,
    this.retentionPolicy = ModuleRetentionPolicy.routeBound,
    this.retentionKey,
    this.retentionExtras,
    this.overrides,
    this.overrideScope,
  });

  /// The module instance to manage.
  final T module;

  /// Widget subtree that can access the module's DI container.
  final Widget child;

  /// Arguments passed to [Configurable.configure] if module implements it.
  ///
  /// Typed as `dynamic` because [ModuleScope] only has one type parameter [T]
  /// (the module type). The actual args type is enforced by the [Configurable]
  /// mixin at the module level — `Configurable<A>.configure(A args)` provides
  /// compile-time safety where it matters. Adding a second type parameter here
  /// would degrade ergonomics for the common case (non-configurable modules).
  final dynamic args;

  /// Builder for loading state UI.
  final WidgetBuilder? loadingBuilder;

  /// Builder for error state UI with retry callback.
  final Widget Function(BuildContext, Object? error, VoidCallback retry)?
  errorBuilder;

  /// How the controller lifecycle is managed.
  ///
  /// Defaults to [ModuleRetentionPolicy.routeBound].
  final ModuleRetentionPolicy retentionPolicy;

  /// Explicit key for KeepAlive cache identity.
  ///
  /// If null, derived from module type, route, and arguments.
  /// Does NOT include [overrideScope] by default.
  final Object? retentionKey;

  /// Additional data for retention key derivation.
  final Map<String, Object?>? retentionExtras;

  /// Overrides applied to module's bindings.
  final void Function(Binder)? overrides;

  /// Override scope tree for this module and its imports.
  ///
  /// Note: Does NOT affect [retentionKey] derivation. See class documentation.
  final ModuleOverrideScope? overrideScope;

  @override
  State<ModuleScope<T>> createState() => _ModuleScopeState<T>();
}

class _ModuleScopeState<T extends Module> extends State<ModuleScope<T>> {
  ModuleController? _controller;
  StreamSubscription<ModuleStatus>? _statusSub;
  ModuleStatus _status = ModuleStatus.initial;
  Object? _error;
  late ModuleRetentionPolicy _policy;
  Object? _retentionKey;
  ModuleRetentionStrategy? _strategy;
  bool _retentionInitialized = false;

  @override
  void initState() {
    super.initState();
    _policy = widget.retentionPolicy;
  }

  @override
  void didUpdateWidget(covariant ModuleScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      oldWidget.retentionPolicy == widget.retentionPolicy,
      'Changing retentionPolicy at runtime is not supported. '
      'Rebuild ModuleScope with a new instance instead.',
    );
    assert(
      oldWidget.retentionKey == widget.retentionKey,
      'Changing retentionKey at runtime is not supported.',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureStrategyInitialized();
    _strategy?.didChangeDependencies();
    _ensureController();
  }

  void _createAndInitController() {
    final factory = ModularityRoot.binderFactoryOf(context);

    // Scope Chaining: Find Parent Binder
    final parentProvider = context
        .dependOnInheritedWidgetOfExactType<ModuleProvider>();
    final parentBinder = parentProvider?.controller.binder;

    // Create Binder with parent
    final binder = factory.create(parentBinder);

    final controller = ModuleController(
      widget.module,
      binder: binder,
      binderFactory: factory,
      overrides: widget.overrides,
      overrideScopeTree: widget.overrideScope,
      interceptors: Modularity.interceptors, // Pass global interceptors
    );

    // Configure the module (args are passed to configure(T args))
    if (widget.args != null) {
      controller.configure(widget.args);
    }

    Modularity.log(
      ModuleLifecycleEvent.created,
      widget.module.runtimeType,
      retentionKey: _retentionKey,
      details: {
        'policy': _policy.name,
        'hasOverrideScope': widget.overrideScope != null,
        'hasArgs': widget.args != null,
      },
    );

    _attachController(controller, runInitialize: true);
  }

  void _attachController(
    ModuleController controller, {
    required bool runInitialize,
  }) {
    _controller = controller;
    _init(runInitialize: runInitialize);
  }

  void _init({required bool runInitialize}) {
    final controller = _controller;
    if (controller == null) return;

    _status = controller.currentStatus;
    if (_status == ModuleStatus.error) {
      _error = controller.lastError;
    }

    _statusSub?.cancel();
    _statusSub = controller.status.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
          if (status == ModuleStatus.error) {
            _error = controller.lastError;
          }
        });
      }
    });

    if (runInitialize) {
      final registry = ModularityRoot.registryOf(context);
      controller.initialize(registry).catchError((_) {
        // Errors are caught in the listen callback
      });
    }
  }

  void _ensureStrategyInitialized() {
    if (_retentionInitialized && _strategy != null) {
      return;
    }

    final parentKey = _RetentionKeyScope.maybeOf(context);
    final derivedKey = deriveRetentionKey(
      module: widget.module,
      context: context,
      explicitKey: widget.retentionKey,
      parentKey: parentKey,
      args: widget.args,
      extras: widget.retentionExtras,
    );
    _retentionKey = derivedKey;

    final binding = ModuleRetentionBinding(
      context: context,
      module: widget.module,
      retentionKey: derivedKey,
      controllerGetter: () => _controller,
      releaseController: ({required bool disposeController}) =>
          _releaseController(disposeController: disposeController),
      retainer: ModularityRoot.retainerOf(context),
      route: ModalRoute.of(context),
    );

    _strategy = buildStrategy(_policy, binding);
    _retentionInitialized = true;
  }

  void _ensureController() {
    if (_controller != null) return;

    final reused = _strategy?.reuseExisting();
    if (reused != null) {
      _attachController(reused, runInitialize: false);
      return;
    }

    _createAndInitController();
    final controller = _controller;
    if (controller != null) {
      _strategy?.onControllerCreated(controller);
    }
  }

  Future<void> _releaseController({required bool disposeController}) async {
    final controller = _controller;
    if (controller == null) return;
    unawaited(_statusSub?.cancel());
    _statusSub = null;
    _controller = null;
    if (disposeController) {
      await controller.dispose();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _controller?.hotReload();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _statusSub = null;
    final strategy = _strategy;
    _strategy = null;

    if (strategy != null) {
      unawaited(
        strategy.onStateDispose().catchError((Object e) {
          debugPrint('[Modularity] Error during strategy dispose: $e');
        }),
      );
    } else {
      unawaited(
        _releaseController(disposeController: true).catchError((Object e) {
          debugPrint('[Modularity] Error during controller dispose: $e');
        }),
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    final Widget content;
    switch (_status) {
      case ModuleStatus.initial:
      case ModuleStatus.loading:
        content = _ModuleScopeLoading(builder: widget.loadingBuilder);
      case ModuleStatus.error:
        content = _ModuleScopeError(
          error: _error,
          onRetry: _retry,
          builder: widget.errorBuilder,
        );
      case ModuleStatus.loaded:
        content = widget.child;
      case ModuleStatus.disposed:
        content = const SizedBox.shrink();
    }

    final provider = ModuleProvider(controller: controller, child: content);

    final key = _retentionKey;
    if (key == null) {
      return provider;
    }

    return _RetentionKeyScope(value: key, child: provider);
  }

  void _retry() {
    unawaited(_handleRetry());
  }

  Future<void> _handleRetry() async {
    if (_strategy != null) {
      await _strategy!.onRetry();
    } else {
      await _releaseController(disposeController: true);
    }

    if (!mounted) return;

    setState(() {
      _status = ModuleStatus.initial;
      _error = null;
    });

    _ensureController();
  }
}

class _ModuleScopeLoading extends StatelessWidget {
  const _ModuleScopeLoading({this.builder});

  final WidgetBuilder? builder;

  @override
  Widget build(BuildContext context) {
    if (builder != null) {
      return builder!(context);
    }

    final defaultBuilder = ModularityRoot.defaultLoadingBuilderOf(context);
    if (defaultBuilder != null) {
      return defaultBuilder(context);
    }

    return const Center(
      child: Text('Loading...', textDirection: TextDirection.ltr),
    );
  }
}

class _ModuleScopeError extends StatelessWidget {
  const _ModuleScopeError({
    required this.error,
    required this.onRetry,
    this.builder,
  });

  final Object? error;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, Object? error, VoidCallback retry)?
  builder;

  @override
  Widget build(BuildContext context) {
    if (builder != null) {
      return builder!(context, error, onRetry);
    }

    final defaultBuilder = ModularityRoot.defaultErrorBuilderOf(context);
    if (defaultBuilder != null) {
      return defaultBuilder(context, error, onRetry);
    }

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Module Init Failed', textDirection: TextDirection.ltr),
            const SizedBox(height: 8),
            Text(error.toString(), textDirection: TextDirection.ltr),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onRetry,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Retry',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: Color(0xFF0000FF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetentionKeyScope extends InheritedWidget {
  const _RetentionKeyScope({required this.value, required super.child});

  final Object value;

  static Object? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_RetentionKeyScope>();
    return scope?.value;
  }

  @override
  bool updateShouldNotify(_RetentionKeyScope oldWidget) =>
      value != oldWidget.value;
}
