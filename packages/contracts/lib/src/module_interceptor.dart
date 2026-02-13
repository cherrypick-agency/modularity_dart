import 'module.dart';

/// Observer for [Module] lifecycle events.
///
/// Implement this interface to add cross-cutting concerns such as logging,
/// analytics, or performance monitoring to every module in the graph.
///
/// Pass interceptors to the `ModuleController` constructor:
///
/// ```dart
/// class TimingInterceptor implements ModuleInterceptor {
///   final _timers = <Type, Stopwatch>{};
///
///   @override
///   void onInit(Module module) {
///     _timers[module.runtimeType] = Stopwatch()..start();
///   }
///
///   @override
///   void onLoaded(Module module) {
///     final elapsed = _timers[module.runtimeType]?.elapsed;
///     print('${module.runtimeType} loaded in $elapsed');
///   }
///
///   @override
///   void onError(Module module, Object error) {
///     print('${module.runtimeType} failed: $error');
///   }
///
///   @override
///   void onDispose(Module module) {
///     _timers.remove(module.runtimeType);
///   }
/// }
/// ```
///
/// See also:
/// - [Module] for the lifecycle hooks that trigger these callbacks.
abstract class ModuleInterceptor {
  /// Called before [Module.onInit] starts.
  void onInit(Module module);

  /// Called after [Module.onInit] completes successfully.
  void onLoaded(Module module);

  /// Called when module initialization fails with [error].
  void onError(Module module, Object error);

  /// Called when the module is being disposed.
  void onDispose(Module module);
}
