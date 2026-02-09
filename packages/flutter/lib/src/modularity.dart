import 'package:flutter/widgets.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

/// Lifecycle event types for module logging.
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

/// Global configuration and helpers for Modularity.
class Modularity {
  Modularity._();

  /// Global RouteObserver for Retention Policy.
  static final RouteObserver<ModalRoute<dynamic>> observer =
      RouteObserver<ModalRoute<dynamic>>();

  /// Global list of ModuleInterceptors.
  static final List<ModuleInterceptor> interceptors = [];

  /// Optional logger for module lifecycle events.
  ///
  /// When set, receives callbacks for:
  /// - Module creation/reuse
  /// - Retention cache register/release/evict
  /// - Route termination handling
  ///
  /// Example:
  /// ```dart
  /// Modularity.lifecycleLogger = (event, type, {retentionKey, details}) {
  ///   debugPrint('[$event] $type key=$retentionKey $details');
  /// };
  /// ```
  static ModuleLifecycleLogger? lifecycleLogger;

  /// Logs a lifecycle event if [lifecycleLogger] is configured.
  static void log(
    ModuleLifecycleEvent event,
    Type moduleType, {
    Object? retentionKey,
    Map<String, Object?>? details,
  }) {
    lifecycleLogger?.call(
      event,
      moduleType,
      retentionKey: retentionKey,
      details: details,
    );
  }

  /// Enables default debug logging in debug mode.
  ///
  /// Prints lifecycle events to console via [debugPrint].
  static void enableDebugLogging() {
    lifecycleLogger = _defaultDebugLogger;
  }

  /// Disables lifecycle logging.
  static void disableLogging() {
    lifecycleLogger = null;
  }

  static void _defaultDebugLogger(
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
}
