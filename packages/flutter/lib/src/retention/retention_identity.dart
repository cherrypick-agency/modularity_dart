import 'package:flutter/widgets.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

/// Derive a stable cache key for a [Module] within the retention system.
///
/// The key uniquely identifies a [ModuleController] within the
/// [ModuleRetainer] cache. Identical keys cause the retainer to return the
/// same cached controller.
///
/// ## Resolution Order
///
/// 1. If [explicitKey] is provided, it is returned as-is.
/// 2. If the [module] implements [RetentionIdentityProvider], its
///    [RetentionIdentityProvider.buildRetentionIdentity] is called. A non-null
///    result is returned directly.
/// 3. Otherwise a composite hash is computed from the module type,
///    [Module.identityKey], the enclosing route, [args], [parentKey], and
///    [extras].
Object deriveRetentionKey({
  required Module module,
  required BuildContext context,
  Object? explicitKey,
  Object? parentKey,
  dynamic args,
  Map<String, Object?>? extras,
}) {
  if (explicitKey != null) return explicitKey;

  final route = ModalRoute.of(context);
  final contextPayload = ModuleRetentionContext(
    moduleType: module.runtimeType,
    moduleIdentityKey: module.identityKey,
    routeName: route?.settings.name,
    routePath: route?.settings.name,
    argumentsHash: _stableHash(args),
    parentKey: parentKey,
    extras: extras,
  );

  if (module is RetentionIdentityProvider) {
    final value = module.buildRetentionIdentity(contextPayload);
    if (value != null) return value;
  }

  return Object.hashAll([
    contextPayload.moduleType,
    _stableHash(contextPayload.moduleIdentityKey),
    contextPayload.routeName,
    contextPayload.routePath,
    contextPayload.argumentsHash,
    contextPayload.parentKey,
    if (contextPayload.extras.isNotEmpty)
      Object.hashAll(
        contextPayload.extras.entries.map(
          (e) => Object.hash(e.key, _stableHash(e.value)),
        ),
      ),
  ]);
}

int? _stableHash(Object? value) {
  if (value == null) return null;
  if (value is num || value is bool || value is String) {
    return Object.hash(value.runtimeType, value);
  }
  if (value is Iterable) {
    return Object.hashAll(value.map(_stableHash).map((hash) => hash ?? 0));
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return Object.hashAll(
      entries.map(
        (entry) =>
            Object.hash(_stableHash(entry.key), _stableHash(entry.value)),
      ),
    );
  }
  return Object.hash(value.runtimeType, value.hashCode);
}
