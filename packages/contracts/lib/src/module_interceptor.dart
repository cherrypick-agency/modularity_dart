import 'module.dart';

/// Interceptor for Module Lifecycle events.
/// Allows global logging, analytics, or debugging hooks.
abstract class ModuleInterceptor {
  /// Called before module initialization starts.
  void onInit(Module module);

  /// Called when module is successfully loaded.
  void onLoaded(Module module);

  /// Called when module initialization fails.
  void onError(Module module, Object error);

  /// Called when module is disposed.
  void onDispose(Module module);
}
