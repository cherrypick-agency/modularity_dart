import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:modularity_core/modularity_core.dart';
import 'module_provider.dart';
import 'modularity_root.dart';
import '../modularity.dart';

class ModuleScope<T extends Module> extends StatefulWidget {
  final T module;
  final Widget child;
  final dynamic args;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext, Object? error, VoidCallback retry)?
      errorBuilder;
  final bool disposeModule;
  final void Function(Binder)? overrides;

  const ModuleScope({
    Key? key,
    required this.module,
    required this.child,
    this.args,
    this.loadingBuilder,
    this.errorBuilder,
    this.disposeModule = true,
    this.overrides,
  }) : super(key: key);

  @override
  _ModuleScopeState<T> createState() => _ModuleScopeState<T>();
}

class _ModuleScopeState<T extends Module> extends State<ModuleScope<T>>
    with RouteAware {
  ModuleController? _controller;
  StreamSubscription? _statusSub;
  ModuleStatus _status = ModuleStatus.initial;
  Object? _error;
  bool _isDisposedByRoute = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Subscribe to RouteObserver for Retention Policy
    final route = ModalRoute.of(context);
    if (route is ModalRoute) {
      // Ensure it's a ModalRoute
      Modularity.observer.subscribe(this, route);
    }

    if (_controller == null) {
      _createAndInitController();
    }
  }

  @override
  void didPop() {
    // RouteBound Strategy: Dispose when popped from stack
    if (widget.disposeModule && !_isDisposedByRoute) {
      _isDisposedByRoute = true;
      _controller?.dispose();
    }
  }

  void _createAndInitController() {
    final factory = ModularityRoot.binderFactoryOf(context);

    // Scope Chaining: Find Parent Binder
    Binder? parentBinder;
    try {
      final parentProvider =
          context.dependOnInheritedWidgetOfExactType<ModuleProvider>();
      parentBinder = parentProvider?.controller.binder;
    } catch (_) {}

    // Create Binder with parent
    final binder = factory.create(parentBinder);

    _controller = ModuleController(
      widget.module,
      binder: binder,
      binderFactory: factory,
      overrides: widget.overrides,
      interceptors: Modularity.interceptors, // Pass global interceptors
    );

    // Конфигурируем (args передаются в configure(T args))
    if (widget.args != null) {
      _controller!.configure(widget.args);
    }

    _init();
  }

  void _init() {
    if (_controller == null) return;

    final registry = ModularityRoot.registryOf(context);

    // Подписка на статус
    _statusSub = _controller!.status.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
          if (status == ModuleStatus.error) {
            _error = _controller!.lastError;
          }
        });
      }
    });

    _controller!.initialize(registry).catchError((e) {
      // Ошибки ловим в listen
    });
  }

  @override
  void dispose() {
    Modularity.observer.unsubscribe(this);
    _statusSub?.cancel();

    // Fallback Strategy: Strict Dispose (on unmount)
    // Если модуль еще не был удален через didPop (например, удаление виджета из дерева без навигации),
    // мы обязаны его удалить, чтобы не было утечек.
    if (widget.disposeModule && !_isDisposedByRoute) {
      _controller?.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const SizedBox.shrink();
    }

    return ModuleProvider(
      controller: _controller!,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case ModuleStatus.initial:
      case ModuleStatus.loading:
        return _buildLoading();

      case ModuleStatus.error:
        return _buildError();

      case ModuleStatus.loaded:
        return widget.child;

      case ModuleStatus.disposed:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLoading() {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }

    final defaultBuilder = ModularityRoot.defaultLoadingBuilderOf(context);
    if (defaultBuilder != null) {
      return defaultBuilder(context);
    }

    // Agnostic Default
    return const Center(
      child: Text('Loading...', textDirection: TextDirection.ltr),
    );
  }

  Widget _buildError() {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _error, _retry);
    }

    final defaultBuilder = ModularityRoot.defaultErrorBuilderOf(context);
    if (defaultBuilder != null) {
      return defaultBuilder(context, _error, _retry);
    }

    // Agnostic Default
    return Center(
      child: SingleChildScrollView(
        // Add scroll to prevent overflow
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Module Init Failed', textDirection: TextDirection.ltr),
            const SizedBox(height: 8),
            Text(_error.toString(), textDirection: TextDirection.ltr),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _retry,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Retry',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: Color(0xFF0000FF))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _retry() {
    _statusSub?.cancel();
    _controller?.dispose();
    _isDisposedByRoute = false;

    setState(() {
      _status = ModuleStatus.initial;
      // Sync creation to avoid empty frame
      _createAndInitController();
    });
  }
}
