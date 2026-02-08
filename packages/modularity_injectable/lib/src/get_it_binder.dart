import 'package:get_it/get_it.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

/// [Binder] implementation backed by two separate [GetIt] instances (private
/// and public scopes), designed for integration with the `injectable` package.
///
/// This variant lives in `modularity_injectable` and manages two isolated
/// [GetIt] containers: one for private module registrations and another for
/// publicly exported dependencies. It tracks registered types manually to
/// support [ExportableBinder] semantics.
///
/// **Note:** A different class also named `GetItBinder` exists in
/// `modularity_get_it` (the standalone adapter). That variant uses a single
/// scoped [GetIt] instance together with [RegistrationAwareBinder] support.
/// Choose the implementation that matches your integration needs.
class GetItBinder implements ExportableBinder, DisposableBinder {
  /// Create a binder with optional [imports] and [parent] scope.
  ///
  /// Each instance gets its own private and public [GetIt] containers.
  GetItBinder({List<Binder> imports = const [], Binder? parent})
    : _privateScope = GetIt.asNewInstance(),
      _publicScope = GetIt.asNewInstance(),
      _imports = imports.toList(),
      _parent = parent {
    // Allow reassignment for hot reload support
    _publicScope.allowReassignment = true;
  }
  final GetIt _privateScope;
  final GetIt _publicScope;
  final List<Binder> _imports;
  final Binder? _parent;

  bool _isExportMode = false;
  bool _publicSealed = false;

  final Set<Type> _privateTypes = {};
  final Set<Type> _publicTypes = {};

  final Map<Type, void Function()> _privateDisposers = {};
  final Map<Type, void Function()> _publicDisposers = {};

  /// Exposes the scoped container used for private registrations.
  GetIt get internalContainer => _privateScope;

  /// Exposes the scoped container storing exported dependencies.
  GetIt get publicContainer => _publicScope;

  @override
  void addImports(List<Binder> binders) {
    _imports.addAll(binders);
  }

  @override
  void enableExportMode() => _isExportMode = true;

  @override
  void disableExportMode() => _isExportMode = false;

  @override
  bool get isExportModeEnabled => _isExportMode;

  @override
  bool get isPublicScopeSealed => _publicSealed;

  @override
  void sealPublicScope() {
    _publicSealed = true;
  }

  @override
  void resetPublicScope() {
    // Clear tracking sets - allowReassignment handles re-registration
    _publicTypes.clear();
    _publicDisposers.clear();
    _publicSealed = false;
  }

  @override
  void registerFactory<T extends Object>(T Function() factory) {
    _register<T>((scope) => scope.registerFactory<T>(factory));
  }

  @override
  void registerLazySingleton<T extends Object>(T Function() factory) {
    _register<T>((scope) => scope.registerLazySingleton<T>(factory));
  }

  @override
  void registerSingleton<T extends Object>(T instance) {
    _register<T>((scope) => scope.registerSingleton<T>(instance));
  }

  @Deprecated('Use registerLazySingleton instead')
  @override
  void singleton<T extends Object>(T Function() factory) =>
      registerLazySingleton(factory);

  @Deprecated('Use registerFactory instead')
  @override
  void factory<T extends Object>(T Function() factory) =>
      registerFactory(factory);

  @override
  T get<T extends Object>() {
    final value = tryGet<T>();
    if (value != null) return value;
    throw DependencyNotFoundException(
      'Dependency of type $T not found in current scope.',
      requestedType: T,
      availableTypes: [..._privateTypes, ..._publicTypes],
    );
  }

  @override
  T? tryGet<T extends Object>() {
    if (_privateScope.isRegistered<T>()) {
      return _privateScope.get<T>();
    }
    if (_publicScope.isRegistered<T>()) {
      return _publicScope.get<T>();
    }

    for (final importedBinder in _imports) {
      final value = importedBinder is ExportableBinder
          ? importedBinder.tryGetPublic<T>()
          : importedBinder.tryGet<T>();
      if (value != null) {
        return value;
      }
    }

    final parentValue = _parent?.tryGet<T>();
    if (parentValue != null) {
      return parentValue;
    }

    return null;
  }

  @override
  T parent<T extends Object>() {
    final value = tryParent<T>();
    if (value != null) {
      return value;
    }
    throw DependencyNotFoundException(
      'Dependency of type $T not found in parent scope.',
      requestedType: T,
      lookupContext: 'parent scope',
    );
  }

  @override
  T? tryParent<T extends Object>() => _parent?.tryGet<T>();

  @override
  bool contains(Type type) {
    if (_privateTypes.contains(type) || _publicTypes.contains(type)) {
      return true;
    }

    for (final imported in _imports) {
      final contains = imported is ExportableBinder
          ? imported.containsPublic(type)
          : imported.contains(type);
      if (contains) return true;
    }

    if (_parent?.contains(type) == true) {
      return true;
    }

    return false;
  }

  @override
  T? tryGetPublic<T extends Object>() {
    if (_publicScope.isRegistered<T>()) {
      return _publicScope.get<T>();
    }
    return null;
  }

  @override
  bool containsPublic(Type type) => _publicTypes.contains(type);

  /// Dispose both GetIt scopes and clear internal state.
  @override
  Future<void> dispose() async {
    _publicTypes.clear();
    _publicDisposers.clear();
    _publicSealed = false;
    _privateTypes.clear();
    _privateDisposers.clear();
    // Reset both scopes
    await _privateScope.reset(dispose: false);
    await _publicScope.reset(dispose: false);
  }

  /// Text dump describing current registrations.
  String debugGraph({bool includeImports = false}) {
    String renderTypes(Set<Type> types) {
      if (types.isEmpty) return '    <empty>';
      return types.map((t) => '    - ${t.toString()}').join('\n');
    }

    final buffer = StringBuffer()
      ..writeln('GetItBinder(${hashCode.toRadixString(16)})')
      ..writeln('  Private:')
      ..writeln(renderTypes(_privateTypes))
      ..writeln('  Public:')
      ..writeln(renderTypes(_publicTypes));

    if (includeImports && _imports.isNotEmpty) {
      buffer.writeln('  Imports:');
      for (final imported in _imports) {
        if (imported is GetItBinder) {
          final nested = imported
              .debugGraph(includeImports: false)
              .split('\n')
              .map((line) => '    $line')
              .join('\n');
          buffer.writeln(nested);
        } else {
          buffer.writeln('    - ${imported.runtimeType}');
        }
      }
    }

    return buffer.toString();
  }

  void _register<T extends Object>(void Function(GetIt scope) registerFn) {
    final scope = _isExportMode ? _publicScope : _privateScope;
    final typeSet = _isExportMode ? _publicTypes : _privateTypes;
    final disposers = _isExportMode ? _publicDisposers : _privateDisposers;

    if (_isExportMode) {
      if (_publicSealed) {
        throw ModuleConfigurationException(
          'Public scope is sealed. Call resetPublicScope() before exporting new types.',
        );
      }
      if (typeSet.contains(T)) {
        throw ModuleConfigurationException(
          'Type $T is already exported. Duplicated exports are not allowed.',
        );
      }
    } else {
      // Private registrations can be overridden, so dispose previous factory.
      if (typeSet.contains(T)) {
        disposers[T]?.call();
        typeSet.remove(T);
        disposers.remove(T);
      }
    }

    registerFn(scope);

    void disposer() {
      scope.unregister<T>();
    }

    typeSet.add(T);
    disposers[T] = disposer;
  }
}

/// [BinderFactory] that produces [GetItBinder] instances.
class GetItBinderFactory implements BinderFactory {
  /// Create a const factory.
  const GetItBinderFactory();

  @override
  Binder create([Binder? parent]) => GetItBinder(parent: parent);
}
