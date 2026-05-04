import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:modularity_core/modularity_core.dart';

import 'module_retainer.dart';

/// Signature for a function that returns the current [ModuleController],
/// or `null` if none is attached.
///
/// Used by [ModuleRetentionBinding] to query the controller held by the
/// owning [ModuleScope] state.
typedef ControllerGetter = ModuleController? Function();

/// Signature for a function that releases (and optionally disposes) the
/// current [ModuleController].
///
/// When [disposeController] is `true`, the controller is fully disposed.
/// When `false`, the reference is detached but the controller remains alive
/// (e.g. held by a [ModuleRetainer]).
typedef ControllerRelease =
    Future<void> Function({required bool disposeController});

/// Binding object that connects a [ModuleRetentionStrategy] to the widget
/// tree, the [ModuleRetainer] cache, and the active [ModuleController].
///
/// Created by [ModuleScope] and passed to the strategy during initialization.
/// Provides everything the strategy needs to manage controller lifecycle
/// without direct access to the widget state.
class ModuleRetentionBinding {
  /// Create a retention binding with all required dependencies.
  ModuleRetentionBinding({
    required this.context,
    required this.module,
    required this.retentionKey,
    required this.controllerGetter,
    required this.releaseController,
    required this.retainer,
    required this.observer,
    this.route,
  });

  /// Build context of the owning [ModuleScope] widget.
  final BuildContext context;

  /// Module instance whose lifecycle is being managed.
  final Module module;

  /// Cache key used for [ModuleRetainer] lookups.
  final Object retentionKey;

  /// Shared [ModuleRetainer] instance that caches controllers across scopes.
  final ModuleRetainer retainer;

  /// Callback that returns the current [ModuleController] held by the scope.
  final ControllerGetter controllerGetter;

  /// Callback that releases (and optionally disposes) the active controller.
  final ControllerRelease releaseController;

  /// [RouteObserver] used for route-bound and keep-alive retention policies.
  final RouteObserver<ModalRoute<dynamic>> observer;

  /// Modal route that owns the current scope, or `null` when outside a route.
  final ModalRoute<dynamic>? route;
}

/// Base class for module retention strategies that govern when a
/// [ModuleController] is reused, created, and disposed.
///
/// Each concrete subclass corresponds to one [ModuleRetentionPolicy] value:
/// - [StrictRetentionStrategy] -- always dispose on unmount.
/// - [RouteBoundRetentionStrategy] -- dispose when the enclosing route pops.
/// - [KeepAliveRetentionStrategy] -- cache in [ModuleRetainer], survive unmount.
///
/// See also:
/// - [buildStrategy] which creates the appropriate strategy for a given policy.
abstract class ModuleRetentionStrategy {
  /// Create a strategy bound to the given [binding].
  ModuleRetentionStrategy(this.binding);

  /// Binding that provides access to the widget tree, retainer, and controller.
  final ModuleRetentionBinding binding;

  /// Return an existing [ModuleController] from the cache, or `null` to
  /// signal that a new controller must be created.
  ModuleController? reuseExisting();

  /// Whether [ModuleScope] may create a new controller when no cached
  /// controller can be reused.
  bool get canCreateController => true;

  /// Handle post-creation bookkeeping for a newly created [controller].
  void onControllerCreated(ModuleController controller);

  /// Release or dispose the controller when the owning [State] is disposed.
  Future<void> onStateDispose();

  /// Dispose the controller immediately, bypassing normal lifecycle rules.
  Future<void> disposeNow();

  /// Reset state and release the controller so a fresh one can be created on
  /// the next build cycle (used after an initialization error).
  Future<void> onRetry();

  /// Respond to dependency changes in the widget tree (called from
  /// [State.didChangeDependencies]).
  void didChangeDependencies();
}

/// Retention strategy for [ModuleRetentionPolicy.strict].
///
/// Dispose the [ModuleController] on every widget unmount; never reuse a
/// cached instance.
class StrictRetentionStrategy extends ModuleRetentionStrategy {
  /// Create a strict retention strategy for the given [binding].
  StrictRetentionStrategy(super.binding);

  @override
  void didChangeDependencies() {}

  @override
  ModuleController? reuseExisting() => null;

  @override
  void onControllerCreated(ModuleController controller) {}

  @override
  Future<void> onRetry() => binding.releaseController(disposeController: true);

  @override
  Future<void> disposeNow() =>
      binding.releaseController(disposeController: true);

  @override
  Future<void> onStateDispose() =>
      binding.releaseController(disposeController: true);
}

/// Retention strategy for [ModuleRetentionPolicy.keepAlive].
///
/// Cache the [ModuleController] in [ModuleRetainer] so it survives widget
/// unmounts. The controller is evicted when its route terminates or when
/// explicitly evicted from the retainer.
class KeepAliveRetentionStrategy extends ModuleRetentionStrategy {
  /// Create a keep-alive retention strategy for the given [binding].
  KeepAliveRetentionStrategy(super.binding);

  bool _registered = false;
  bool _released = false;
  bool _routeTerminationHandled = false;

  @override
  void didChangeDependencies() {}

  @override
  ModuleController? reuseExisting() {
    if (_routeTerminationHandled) {
      return null;
    }
    final controller = binding.retainer.acquire(binding.retentionKey);
    if (controller != null) {
      _registered = true;
      _released = false;
      _routeTerminationHandled = false;
    }
    return controller;
  }

  @override
  bool get canCreateController => !_routeTerminationHandled;

  @override
  void onControllerCreated(ModuleController controller) {
    if (_routeTerminationHandled) {
      return;
    }
    if (_registered) return;
    binding.retainer.register(
      key: binding.retentionKey,
      controller: controller,
      policy: ModuleRetentionPolicy.keepAlive,
      route: binding.route,
      onRouteTerminated: _handleRouteTermination,
    );
    _registered = true;
    _released = false;
    _routeTerminationHandled = false;
  }

  @override
  Future<void> onRetry() async {
    if (_registered) {
      await binding.releaseController(disposeController: false);
      await binding.retainer.evict(binding.retentionKey);
    } else {
      await binding.releaseController(disposeController: true);
    }
    _registered = false;
    _released = false;
    _routeTerminationHandled = false;
  }

  @override
  Future<void> disposeNow() async =>
      _evictRetainedController(disposeController: true);

  @override
  Future<void> onStateDispose() async {
    if (!_registered) {
      await binding.releaseController(disposeController: true);
      return;
    }
    if (_released) return;
    _released = true;
    await binding.releaseController(disposeController: false);
    await binding.retainer.release(binding.retentionKey);
  }

  Future<void> _evictRetainedController({
    required bool disposeController,
  }) async {
    if (!_registered) {
      await binding.releaseController(disposeController: true);
      return;
    }
    final controllerIsAttached = binding.controllerGetter() != null;
    await binding.releaseController(
      disposeController: disposeController && controllerIsAttached,
    );
    await binding.retainer.evict(
      binding.retentionKey,
      disposeController: disposeController && !controllerIsAttached,
    );
    _registered = false;
    _released = true;
    _routeTerminationHandled = true;
  }

  Future<void> _handleRouteTermination() async {
    if (_routeTerminationHandled) return;
    _routeTerminationHandled = true;
    await _evictRetainedController(disposeController: true);
  }
}

/// Retention strategy for [ModuleRetentionPolicy.routeBound].
///
/// Subscribe to the enclosing [ModalRoute] via [RouteAware] and dispose the
/// [ModuleController] when the route is popped or removed from the navigator.
class RouteBoundRetentionStrategy extends ModuleRetentionStrategy
    with RouteAware {
  /// Create a route-bound retention strategy for the given [binding].
  RouteBoundRetentionStrategy(super.binding);

  ModalRoute<dynamic>? _route;
  bool _disposedByRoute = false;

  @override
  void didChangeDependencies() {
    final route = ModalRoute.of(binding.context);
    if (route == null) {
      return;
    }
    if (_route == route) {
      return;
    }
    if (_route != null) {
      binding.observer.unsubscribe(this);
    }
    _route = route;
    binding.observer.subscribe(this, route);
  }

  @override
  ModuleController? reuseExisting() => null;

  @override
  void onControllerCreated(ModuleController controller) {}

  @override
  Future<void> onRetry() async {
    _disposedByRoute = false;
    await binding.releaseController(disposeController: true);
  }

  @override
  Future<void> disposeNow() async {
    if (_disposedByRoute) return;
    _disposedByRoute = true;
    binding.observer.unsubscribe(this);
    _route = null;
    await binding.releaseController(disposeController: true);
  }

  @override
  Future<void> onStateDispose() async {
    binding.observer.unsubscribe(this);
    if (!_disposedByRoute) {
      await binding.releaseController(disposeController: true);
    }
  }

  /// Dispose the controller when the route is popped off the navigator.
  @override
  void didPop() {
    disposeNow();
  }

  // Note: Route removal (Navigator.removeRoute) is handled by RouteObserver
  // unsubscription in onStateDispose(). Flutter's RouteAware mixin does not
  // include a didRemove() callback, so route removal cannot be observed
  // through the RouteObserver/RouteAware mechanism. The didPop() callback
  // covers the standard pop navigation case.
}

/// Create the appropriate [ModuleRetentionStrategy] for the given [policy]
/// and [binding].
///
/// Returns a [StrictRetentionStrategy], [RouteBoundRetentionStrategy], or
/// [KeepAliveRetentionStrategy] depending on the policy value.
ModuleRetentionStrategy buildStrategy(
  ModuleRetentionPolicy policy,
  ModuleRetentionBinding binding,
) {
  switch (policy) {
    case ModuleRetentionPolicy.routeBound:
      return RouteBoundRetentionStrategy(binding);
    case ModuleRetentionPolicy.keepAlive:
      return KeepAliveRetentionStrategy(binding);
    case ModuleRetentionPolicy.strict:
      return StrictRetentionStrategy(binding);
  }
}
