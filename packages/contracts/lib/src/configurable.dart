/// Interface for modules that require runtime configuration before
/// initialization.
///
/// Implement this on a [Module] subclass to receive strongly-typed
/// arguments (e.g. a route parameter or feature flag) before [Module.binds]
/// and [Module.onInit] are called.
///
/// ```dart
/// class UserModule extends Module implements Configurable<String> {
///   late final String _userId;
///
///   @override
///   void configure(String args) => _userId = args;
///
///   @override
///   void binds(Binder i) {
///     i.registerLazySingleton<UserRepo>(
///       () => UserRepo(userId: _userId),
///     );
///   }
/// }
/// ```
///
/// See also:
/// - [Module] for the base module contract.
abstract class Configurable<T> {
  /// Receives the configuration [args] of type [T].
  ///
  /// Called by the framework (via `ModuleController.configure`) before
  /// [Module.binds] and [Module.onInit].
  void configure(T args);
}
