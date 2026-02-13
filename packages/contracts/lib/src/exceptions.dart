/// Exception types for the Modularity framework.
///
/// All exceptions extend [ModularityException], which implements [Exception]
/// for backward compatibility with existing catch clauses.
///
/// ```dart
/// try {
///   await controller.initialize(registry);
/// } on CircularDependencyException catch (e) {
///   print('Cycle: ${e.dependencyChain}');
/// } on DependencyNotFoundException catch (e) {
///   print('Missing: ${e.requestedType}, available: ${e.availableTypes}');
/// } on ModularityException catch (e) {
///   print('Framework error: ${e.message}');
/// }
/// ```
library;

import 'module.dart';

/// Base exception for all Modularity framework errors.
///
/// Provides a human-readable [message] and serves as the root of the
/// exception hierarchy. Catch this type to handle any Modularity error
/// generically.
///
/// ```dart
/// try {
///   binder.get<MyService>();
/// } on ModularityException catch (e) {
///   debugPrint(e.message);
/// }
/// ```
///
/// See also:
/// - [DependencyNotFoundException] for missing dependencies.
/// - [CircularDependencyException] for import cycles.
/// - [ModuleConfigurationException] for configuration errors.
/// - [ModuleLifecycleException] for lifecycle failures.
class ModularityException implements Exception {
  /// Creates a Modularity exception with the given [message].
  const ModularityException(this.message);

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() => 'ModularityException: $message';
}

/// Thrown when a requested dependency cannot be found in the binder chain.
///
/// The lookup follows the resolution order: **Local -> Imports -> Parent**.
/// If the type is not found at any level, this exception is thrown.
///
/// Use [availableTypes] to inspect which types are registered in the
/// current scope for debugging purposes.
///
/// ```dart
/// try {
///   final service = binder.get<UnregisteredService>();
/// } on DependencyNotFoundException catch (e) {
///   print('Wanted: ${e.requestedType}');
///   print('Have: ${e.availableTypes}');
/// }
/// ```
class DependencyNotFoundException extends ModularityException {
  /// Create a dependency-not-found exception.
  const DependencyNotFoundException(
    super.message, {
    required this.requestedType,
    this.availableTypes = const [],
    this.lookupContext,
  });

  /// The type that was requested but not found.
  final Type requestedType;

  /// Types currently available in the scope where the lookup failed.
  final List<Type> availableTypes;

  /// Optional description of where the lookup was performed
  /// (e.g. 'parent scope', 'GetItBinder scope').
  final String? lookupContext;

  @override
  String toString() {
    final buffer = StringBuffer('DependencyNotFoundException: $message');
    if (availableTypes.isNotEmpty) {
      buffer
        ..write('\nAvailable types: [')
        ..write(availableTypes.map((t) => t.toString()).join(', '))
        ..write(']');
    }
    if (lookupContext != null) {
      buffer
        ..write('\nLookup context: ')
        ..write(lookupContext);
    }
    return buffer.toString();
  }
}

/// Thrown when a circular dependency is detected in the module import graph.
///
/// The [dependencyChain] shows the full cycle path, making it easy to
/// identify which modules form the cycle.
///
/// ```dart
/// // A -> B -> A  (cycle!)
/// try {
///   await controller.initialize(registry);
/// } on CircularDependencyException catch (e) {
///   print(e.dependencyChain); // [ModuleA, ModuleB, ModuleA]
/// }
/// ```
class CircularDependencyException extends ModularityException {
  /// Create a circular-dependency exception.
  const CircularDependencyException(
    super.message, {
    this.dependencyChain = const [],
  });

  /// The chain of module types that form the circular dependency.
  ///
  /// The last element points back to an earlier element in the list.
  final List<Type> dependencyChain;

  @override
  String toString() {
    final buffer = StringBuffer('CircularDependencyException: $message');
    if (dependencyChain.isNotEmpty) {
      buffer
        ..write('\nDependency chain: ')
        ..write(dependencyChain.map((t) => t.toString()).join(' -> '));
    }
    return buffer.toString();
  }
}

/// Thrown when a module is incorrectly configured.
///
/// Covers cases such as:
/// - Sealed public scope violations
/// - Duplicate export registrations
/// - Missing required providers (e.g. `ModularityRoot`, `ModuleProvider`)
/// - Wrong binder type for an integration
///
/// ```dart
/// try {
///   binder.sealPublicScope();
///   binder.enableExportMode();
///   binder.registerFactory<Foo>(() => Foo()); // throws!
/// } on ModuleConfigurationException catch (e) {
///   print(e.moduleType); // null or the offending module type
/// }
/// ```
class ModuleConfigurationException extends ModularityException {
  /// Create a module-configuration exception.
  const ModuleConfigurationException(super.message, {this.moduleType});

  /// The module type that is misconfigured, if applicable.
  final Type? moduleType;

  @override
  String toString() {
    final buffer = StringBuffer('ModuleConfigurationException: $message');
    if (moduleType != null) {
      buffer
        ..write('\nModule type: ')
        ..write(moduleType);
    }
    return buffer.toString();
  }
}

/// Thrown when a module lifecycle operation fails.
///
/// Covers cases such as:
/// - Configuration type mismatch in [Configurable.configure]
/// - Dependent module load failure
/// - Duplicate retention key registration
///
/// ```dart
/// try {
///   await controller.initialize(registry);
/// } on ModuleLifecycleException catch (e) {
///   print('${e.moduleType} failed in state ${e.state}');
/// }
/// ```
class ModuleLifecycleException extends ModularityException {
  /// Create a module-lifecycle exception.
  const ModuleLifecycleException(super.message, {this.moduleType, this.state});

  /// The module type where the lifecycle error occurred.
  final Type? moduleType;

  /// The [ModuleStatus] at the time of the error, if known.
  final ModuleStatus? state;

  @override
  String toString() {
    final buffer = StringBuffer('ModuleLifecycleException: $message');
    if (moduleType != null) {
      buffer
        ..write('\nModule type: ')
        ..write(moduleType);
    }
    if (state != null) {
      buffer
        ..write('\nState: ')
        ..write(state);
    }
    return buffer.toString();
  }
}
