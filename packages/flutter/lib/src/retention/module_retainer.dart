import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:modularity_core/modularity_core.dart';

import '../modularity.dart';

/// Snapshot of a retained module entry for debugging purposes.
///
/// Provides visibility into the retention cache state without exposing
/// mutable internal state.
class ModuleRetainerEntrySnapshot {
  /// Create a snapshot of a retained module entry.
  ModuleRetainerEntrySnapshot({
    required this.key,
    required this.policy,
    required this.refCount,
    required this.lastAccessed,
    required this.moduleType,
  });

  /// Retention cache key that uniquely identifies this entry.
  final Object key;

  /// Retention policy governing the lifecycle of the cached controller.
  final ModuleRetentionPolicy policy;

  /// Number of active references currently holding this entry alive.
  final int refCount;

  /// Timestamp of the most recent [acquire] or [register] call for this entry.
  final DateTime lastAccessed;

  /// Runtime type of the [Module] associated with the cached controller.
  final Type moduleType;
}

class _ModuleRetainerEntry {
  _ModuleRetainerEntry({
    required this.controller,
    required this.policy,
    required this.lastAccessed,
    ModalRoute<dynamic>? route,
    FutureOr<void> Function()? onRouteTerminated,
    this.refCount = 0,
  }) : moduleType = controller.module.runtimeType {
    attachRoute(route: route, onRouteTerminated: onRouteTerminated);
  }

  final ModuleController controller;
  final ModuleRetentionPolicy policy;
  final Type moduleType;
  int refCount;
  DateTime lastAccessed;
  bool _disposed = false;
  ModalRoute<dynamic>? _route;
  FutureOr<void> Function()? _onRouteTerminated;
  bool _routeNotified = false;
  int _routeToken = 0;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _unsubscribeRoute();
    await controller.dispose();
  }

  void attachRoute({
    ModalRoute<dynamic>? route,
    FutureOr<void> Function()? onRouteTerminated,
  }) {
    _onRouteTerminated = onRouteTerminated;
    if (route == null) {
      _routeToken++;
      _route = null;
      return;
    }
    if (_route == route) return;
    _route = route;
    _routeNotified = false;
    final currentToken = ++_routeToken;
    route.popped.whenComplete(() {
      if (_routeToken == currentToken) {
        unawaited(_notifyRouteTermination());
      }
    });
  }

  Future<void> _notifyRouteTermination() async {
    if (_routeNotified) return;
    _routeNotified = true;
    Modularity.log(
      ModuleLifecycleEvent.routeTerminated,
      moduleType,
      details: {'routeType': _route.runtimeType.toString()},
    );
    if (_onRouteTerminated != null) {
      await _onRouteTerminated!();
    }
  }

  void _unsubscribeRoute() {
    _routeToken++;
    _route = null;
  }
}

/// Cache for [ModuleController] instances with KeepAlive retention policy.
///
/// ## Retention Key vs Override Scope
///
/// **Important**: The retainer uses [retentionKey] for cache lookup, which is
/// independent of [ModuleOverrideScope]. This is by design:
///
/// - **retentionKey** determines cache identity (derived from module type,
///   route, arguments, and explicit key).
/// - **overrideScope** affects DI bindings within the module's dependency graph
///   but does NOT affect retention cache identity.
///
/// ### Implications
///
/// Two [ModuleScope] widgets of the same module type with:
/// - Same retentionKey but different overrideScopes → **share** the same
///   cached controller. The first scope's overrideScope wins.
/// - Different retentionKeys but same overrideScope → have **separate**
///   cached controllers.
///
/// If you need override-aware caching, provide explicit [retentionKey] that
/// incorporates the scope identity:
///
/// ```dart
/// ModuleScope(
///   module: MyModule(),
///   retentionPolicy: ModuleRetentionPolicy.keepAlive,
///   retentionKey: 'my-module-${overrideScope.hashCode}',
///   overrideScope: overrideScope,
///   child: ...,
/// )
/// ```
///
/// ## Thread Safety
///
/// This class is NOT thread-safe. All operations must be performed on the
/// main isolate.
class ModuleRetainer {
  final Map<Object, _ModuleRetainerEntry> _entries = {};

  /// Return whether a controller with the given [key] exists in the cache.
  bool contains(Object key) => _entries.containsKey(key);

  /// Return the cached [ModuleController] for [key] without incrementing the
  /// reference count, or `null` if no entry exists.
  ModuleController? peek(Object key) => _entries[key]?.controller;

  /// Return the cached [ModuleController] for [key] and increment its
  /// reference count, or `null` if no entry exists.
  ModuleController? acquire(Object key) {
    final entry = _entries[key];
    if (entry == null) return null;
    entry.refCount++;
    entry.lastAccessed = DateTime.now();
    Modularity.log(
      ModuleLifecycleEvent.reused,
      entry.moduleType,
      retentionKey: key,
      details: {'refCount': entry.refCount},
    );
    return entry.controller;
  }

  /// Register a [ModuleController] in the cache under [key].
  ///
  /// Throw [ModuleLifecycleException] if [key] is already registered.
  /// Optionally attach a [route] so the entry is automatically evicted when
  /// the route is popped, invoking [onRouteTerminated] as a callback.
  void register({
    required Object key,
    required ModuleController controller,
    ModuleRetentionPolicy policy = ModuleRetentionPolicy.keepAlive,
    int initialRefCount = 1,
    ModalRoute<dynamic>? route,
    FutureOr<void> Function()? onRouteTerminated,
  }) {
    if (_entries.containsKey(key)) {
      throw ModuleLifecycleException(
        'Retention key "$key" is already registered. '
        'Call release/evict before registering again.',
        moduleType: controller.module.runtimeType,
      );
    }
    final entry = _ModuleRetainerEntry(
      controller: controller,
      policy: policy,
      lastAccessed: DateTime.now(),
      refCount: initialRefCount,
      route: route,
      onRouteTerminated: onRouteTerminated,
    );
    _entries[key] = entry;
    Modularity.log(
      ModuleLifecycleEvent.registered,
      controller.module.runtimeType,
      retentionKey: key,
      details: {
        'policy': policy.name,
        'refCount': initialRefCount,
        'hasRoute': route != null,
      },
    );
  }

  /// Decrement the reference count for [key].
  ///
  /// If [disposeIfOrphaned] is `true` and the reference count drops to zero,
  /// remove the entry and dispose its [ModuleController].
  Future<void> release(Object key, {bool disposeIfOrphaned = false}) async {
    final entry = _entries[key];
    if (entry == null) return;
    if (entry.refCount > 0) {
      entry.refCount--;
    }
    Modularity.log(
      ModuleLifecycleEvent.released,
      entry.moduleType,
      retentionKey: key,
      details: {
        'refCount': entry.refCount,
        'disposeIfOrphaned': disposeIfOrphaned,
      },
    );
    if (disposeIfOrphaned && entry.refCount <= 0) {
      final removed = _entries.remove(key) ?? entry;
      await removed.dispose();
      Modularity.log(
        ModuleLifecycleEvent.disposed,
        removed.moduleType,
        retentionKey: key,
        details: {'reason': 'orphaned'},
      );
    }
  }

  /// Remove the entry for [key] from the cache regardless of reference count.
  ///
  /// When [disposeController] is `true` (the default), the underlying
  /// [ModuleController] is disposed after removal.
  Future<void> evict(Object key, {bool disposeController = true}) async {
    final entry = _entries.remove(key);
    if (entry == null) return;
    Modularity.log(
      ModuleLifecycleEvent.evicted,
      entry.moduleType,
      retentionKey: key,
      details: {'disposeController': disposeController},
    );
    if (disposeController) {
      await entry.dispose();
      Modularity.log(
        ModuleLifecycleEvent.disposed,
        entry.moduleType,
        retentionKey: key,
        details: {'reason': 'evicted'},
      );
    }
  }

  /// Return a list of [ModuleRetainerEntrySnapshot] instances reflecting the
  /// current cache state, intended for debugging and testing.
  List<ModuleRetainerEntrySnapshot> debugSnapshot() {
    return _entries.entries
        .map(
          (e) => ModuleRetainerEntrySnapshot(
            key: e.key,
            policy: e.value.policy,
            refCount: e.value.refCount,
            lastAccessed: e.value.lastAccessed,
            moduleType: e.value.moduleType,
          ),
        )
        .toList(growable: false);
  }
}
