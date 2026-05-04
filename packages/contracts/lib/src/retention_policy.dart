import 'module.dart';

/// Defines how a `ModuleScope` manages the lifetime of a module relative
/// to navigation and widget lifecycle events.
///
/// See also:
/// - `ModuleScope` in `modularity_flutter` where the policy is applied.
/// - [ModuleRetentionContext] for identity computation.
enum ModuleRetentionPolicy {
  /// Dispose when the owning route leaves the navigator stack
  /// (default RouteObserver-driven behaviour).
  routeBound,

  /// Keep the module alive across widget unmounts. The controller is cached
  /// and must be released manually or when all interested scopes detach.
  keepAlive,

  /// Always dispose as soon as the corresponding `ModuleScope` leaves the tree.
  strict,
}

/// Context payload used to derive a deterministic retention identity for a
/// module instance.
///
/// Passed to [RetentionIdentityProvider.buildRetentionIdentity] so that the
/// module can produce a stable key based on its type, module identity, route,
/// and arguments.
class ModuleRetentionContext {
  /// Creates a retention context for the given [moduleType].
  ModuleRetentionContext({
    required this.moduleType,
    this.moduleIdentityKey,
    this.routeName,
    this.routePath,
    this.argumentsHash,
    this.parentKey,
    Map<String, Object?>? extras,
  }) : extras = extras == null ? const {} : Map.unmodifiable(extras);

  /// Runtime type of the module instance.
  final Type moduleType;

  /// Optional identity from [Module.identityKey].
  final Object? moduleIdentityKey;

  /// Optional router-provided name (e.g. `RouteSettings.name`).
  final String? routeName;

  /// Optional router-specific path (e.g. `/users/:id`).
  final String? routePath;

  /// Precomputed hash of the arguments/config passed to the module.
  final int? argumentsHash;

  /// Identity of the parent scope if available (allows nested modules to
  /// inherit a stable namespace).
  final Object? parentKey;

  /// Additional metadata supplied by adapter layers.
  final Map<String, Object?> extras;
}

/// Optional mixin for modules that compute their own retention key.
///
/// When a module mixes in [RetentionIdentityProvider], the `ModuleScope`
/// calls [buildRetentionIdentity] instead of using the default identity
/// strategy. This allows modules to produce stable keys based on route
/// parameters or other contextual data.
///
/// ```dart
/// class UserModule extends Module with RetentionIdentityProvider {
///   @override
///   Object? buildRetentionIdentity(ModuleRetentionContext context) {
///     return 'user-${context.argumentsHash}';
///   }
///
///   @override
///   void binds(Binder i) { /* ... */ }
/// }
/// ```
mixin RetentionIdentityProvider on Module {
  /// Returns an object that uniquely identifies this module instance for
  /// retention purposes. The value must be stable across widget rebuilds.
  Object? buildRetentionIdentity(ModuleRetentionContext context);
}
