import 'binder.dart';

/// Factory for creating [Binder] instances.
///
/// Provide a custom [BinderFactory] to the `ModuleController` to swap the
/// DI container implementation (e.g. `GetItBinder` instead of the default
/// `SimpleBinder`).
///
/// ```dart
/// class GetItBinderFactory implements BinderFactory {
///   @override
///   Binder create([Binder? parent]) => GetItBinder(parent: parent);
/// }
///
/// final controller = ModuleController(
///   AppModule(),
///   binderFactory: GetItBinderFactory(),
/// );
/// ```
///
/// See also:
/// - [Binder] for the interface that created instances must implement.
abstract class BinderFactory {
  /// Creates a new [Binder], optionally chaining it to a [parent] scope
  /// for hierarchical resolution.
  Binder create([Binder? parent]);
}
