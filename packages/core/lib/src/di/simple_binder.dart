import 'package:modularity_contracts/modularity_contracts.dart';

enum _DependencyType { factory, singleton, instance }

class _Registration {
  _Registration({required this.type, required this.factory, this.instance});
  final _DependencyType type;
  Object Function() factory;
  Object? instance;
}

/// Pure-Dart, map-based [Binder] implementation with no external dependencies.
///
/// [SimpleBinder] maintains two separate registration maps — **private** and
/// **public** — to support the [ExportableBinder] contract. It also
/// implements [RegistrationAwareBinder] for hot-reload support and
/// [DisposableBinder] for resource cleanup.
///
/// Dependency resolution follows the order:
/// 1. Local private scope
/// 2. Local public scope
/// 3. Imported binders (public exports only)
/// 4. Parent binder
///
/// ```dart
/// final binder = SimpleBinder();
/// binder.registerLazySingleton<Logger>(() => ConsoleLogger());
/// binder.registerFactory<ApiClient>(() => ApiClient(binder.get<Logger>()));
///
/// final client = binder.get<ApiClient>(); // new instance each time
/// ```
///
/// See also:
/// - [SimpleBinderFactory] which produces [SimpleBinder] instances.
/// - [ExportableBinder] for the public/private scope contract.
class SimpleBinder
    implements ExportableBinder, RegistrationAwareBinder, DisposableBinder {
  /// Creates a [SimpleBinder] with optional imported binders and a [parent]
  /// scope for hierarchical resolution.
  SimpleBinder({List<Binder> imports = const [], Binder? parent})
    : _imports = imports.toList(),
      _parent = parent;
  final Map<Type, _Registration> _privateRegistrations = {};
  final Map<Type, _Registration> _publicRegistrations = {};

  /// List of imported modules (their public binders).
  final List<Binder> _imports;

  /// Parent binder (Scope chaining).
  final Binder? _parent;

  /// When true, registrations go to _publicRegistrations.
  bool _isExportMode = false;

  /// After exports complete the public scope may be sealed to prevent
  /// post-registration. Hot reload can reset this flag.
  bool _publicSealed = false;

  final List<RegistrationStrategy> _strategyStack = [
    RegistrationStrategy.replace,
  ];

  /// Append the given [Binder] list to the set of imported scopes.
  @override
  void addImports(List<Binder> binders) {
    _imports.addAll(binders);
  }

  /// Enable export mode (registrations go to the public scope).
  @override
  void enableExportMode() => _isExportMode = true;

  /// Disable export mode (registrations go to the private scope).
  @override
  void disableExportMode() => _isExportMode = false;

  /// Return `true` when registrations are directed to the public scope.
  @override
  bool get isExportModeEnabled => _isExportMode;

  /// Return `true` when the public scope is sealed and rejects new registrations.
  @override
  bool get isPublicScopeSealed => _publicSealed;

  /// Seal the public scope so that further export-mode registrations throw.
  @override
  void sealPublicScope() {
    _publicSealed = true;
  }

  /// Unseal the public scope to allow re-registration (e.g. during hot reload).
  @override
  void resetPublicScope() {
    _publicSealed = false;
  }

  /// Register a lazy singleton that is instantiated on first [get] call.
  @override
  void registerLazySingleton<T extends Object>(T Function() factory) {
    _register<T>(
      _Registration(type: _DependencyType.singleton, factory: factory),
    );
  }

  /// Register a factory that creates a new instance on every [get] call.
  @override
  void registerFactory<T extends Object>(T Function() factory) {
    _register<T>(
      _Registration(type: _DependencyType.factory, factory: factory),
    );
  }

  /// Register an already-created instance as an eager singleton.
  @override
  void registerSingleton<T extends Object>(T instance) {
    _register<T>(
      _Registration(
        type: _DependencyType.instance,
        factory: () => instance,
        instance: instance,
      ),
    );
  }

  void _register<T extends Object>(_Registration reg) {
    final target = _isExportMode ? _publicRegistrations : _privateRegistrations;
    final existing = target[T];
    final isPreserve =
        registrationStrategy == RegistrationStrategy.preserveExisting;

    if (_isExportMode && _publicSealed) {
      throw ModuleConfigurationException(
        'Public scope is sealed. Call resetPublicScope() before registering new exports.',
      );
    }

    if (existing != null) {
      if (_isExportMode &&
          !isPreserve &&
          registrationStrategy == RegistrationStrategy.replace) {
        throw ModuleConfigurationException(
          'Type $T is already exported in this module. Duplicate exports are not allowed.',
        );
      }

      if (isPreserve) {
        existing.factory = reg.factory;
        return;
      }
    }

    target[T] = reg;
  }

  /// Resolve a dependency of type [T] or throw [DependencyNotFoundException].
  ///
  /// Lookup order: local private scope, local public scope, imports, parent.
  @override
  T get<T extends Object>() {
    final object = tryGet<T>();
    if (object == null) {
      throw DependencyNotFoundException(
        'Dependency of type $T not found.\n'
        'Checked: Current Scope, Imports, Parent.',
        requestedType: T,
        availableTypes: [
          ..._privateRegistrations.keys,
          ..._publicRegistrations.keys,
        ],
      );
    }
    return object;
  }

  /// Try to resolve a dependency of type [T], returning `null` if not found.
  ///
  /// Searches local scope, then imports (public exports only), then parent.
  @override
  T? tryGet<T extends Object>() {
    // 1. Search locally (Private first, then Public)
    if (_privateRegistrations.containsKey(T)) {
      return _resolveRegistration<T>(_privateRegistrations[T]!);
    }
    if (_publicRegistrations.containsKey(T)) {
      return _resolveRegistration<T>(_publicRegistrations[T]!);
    }

    // 2. Search in imports (ONLY Public exports of imported modules)
    for (final importedBinder in _imports) {
      if (importedBinder is ExportableBinder) {
        final found = importedBinder.tryGetPublic<T>();
        if (found != null) return found;
      } else {
        final found = importedBinder.tryGet<T>();
        if (found != null) return found;
      }
    }

    // 3. Search in Parent (Implicit scope chaining)
    // Search parent as a regular get (it decides its own access rights)
    final parentFound = _parent?.tryGet<T>();
    if (parentFound != null) return parentFound;

    return null;
  }

  /// Resolve a dependency of type [T] from the parent scope or throw.
  @override
  T parent<T extends Object>() {
    final object = tryParent<T>();
    if (object == null) {
      throw DependencyNotFoundException(
        'Dependency of type $T not found in parent scope.',
        requestedType: T,
        lookupContext: 'parent scope',
      );
    }
    return object;
  }

  /// Try to resolve a dependency of type [T] from the parent scope.
  @override
  T? tryParent<T extends Object>() {
    return _parent?.tryGet<T>();
  }

  /// Return `true` if [type] is registered in any reachable scope.
  ///
  /// Checks local registrations, imported public exports, and the parent chain.
  @override
  bool contains(Type type) {
    // 1. Local
    if (_privateRegistrations.containsKey(type) ||
        _publicRegistrations.containsKey(type)) {
      return true;
    }

    // 2. Imports
    for (final importedBinder in _imports) {
      // Correctly check only public exports for imports
      if (importedBinder is ExportableBinder) {
        if (importedBinder.containsPublic(type)) return true;
      } else {
        if (importedBinder.contains(type)) return true;
      }
    }

    // 3. Parent
    if (_parent?.contains(type) == true) return true;

    return false;
  }

  /// Searches ONLY in public dependencies (for use by other modules).
  @override
  T? tryGetPublic<T extends Object>() {
    if (_publicRegistrations.containsKey(T)) {
      return _resolveRegistration<T>(_publicRegistrations[T]!);
    }
    return null;
  }

  /// Return `true` if [type] is registered in the public (exported) scope.
  @override
  bool containsPublic(Type type) {
    return _publicRegistrations.containsKey(type);
  }

  T _resolveRegistration<T extends Object>(_Registration reg) {
    if (reg.type == _DependencyType.instance) {
      return reg.instance as T;
    }

    if (reg.type == _DependencyType.singleton) {
      reg.instance ??= reg.factory();
      return reg.instance as T;
    }

    // Factory
    return reg.factory() as T;
  }

  /// Release resources.
  @override
  Future<void> dispose() async {
    _privateRegistrations.clear();
    _publicRegistrations.clear();
    _publicSealed = false;
  }

  /// Return the currently active [RegistrationStrategy].
  @override
  RegistrationStrategy get registrationStrategy => _strategyStack.last;

  /// Execute [body] under the given [RegistrationStrategy], restoring the
  /// previous strategy when [body] completes.
  @override
  T runWithStrategy<T>(RegistrationStrategy strategy, T Function() body) {
    _strategyStack.add(strategy);
    try {
      return body();
    } finally {
      _strategyStack.removeLast();
    }
  }

  /// Returns a human-readable text dump of the current binder state,
  /// listing private and public registrations (and optionally imports).
  String debugGraph({bool includeImports = false}) {
    final buffer = StringBuffer()
      ..writeln('SimpleBinder(${hashCode.toRadixString(16)})')
      ..writeln('  Private:')
      ..writeln(
        _privateRegistrations.keys
            .map((t) => '    - ${t.toString()}')
            .join('\n')
            .trimRight(),
      )
      ..writeln('  Public:')
      ..writeln(
        _publicRegistrations.keys
            .map((t) => '    - ${t.toString()}')
            .join('\n')
            .trimRight(),
      );

    if (includeImports && _imports.isNotEmpty) {
      buffer.writeln('  Imports:');
      for (final imported in _imports) {
        if (imported is SimpleBinder) {
          buffer.writeln(
            imported
                .debugGraph(includeImports: false)
                .split('\n')
                .map((line) => '    $line')
                .join('\n'),
          );
        } else {
          buffer.writeln('    - ${imported.runtimeType}');
        }
      }
    }

    return buffer.toString();
  }
}
