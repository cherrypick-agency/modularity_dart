import 'package:modularity_contracts/modularity_contracts.dart';

/// Classify how a dependency is registered in a [Binder].
enum DependencyRegistrationKind {
  /// Registered as a lazy singleton that is created on first access.
  singleton,

  /// Registered as a factory that produces a new instance on every access.
  factory,

  /// Registered as a pre-built instance (eager singleton).
  instance,
}

/// Provide a human-readable label for each [DependencyRegistrationKind] value.
extension DependencyRegistrationKindLabel on DependencyRegistrationKind {
  /// Return a lowercase label suitable for display in graphs and logs.
  String get label {
    switch (this) {
      case DependencyRegistrationKind.singleton:
        return 'singleton';
      case DependencyRegistrationKind.factory:
        return 'factory';
      case DependencyRegistrationKind.instance:
        return 'instance';
    }
  }
}

/// Hold metadata about a single dependency registration.
class DependencyRecord {
  /// Create a record for the given [type] registered with [kind].
  DependencyRecord(this.type, this.kind);

  /// The runtime type of the registered dependency.
  final Type type;

  /// The registration strategy used (singleton, factory, or instance).
  final DependencyRegistrationKind kind;

  /// Return a human-readable string combining [type] and [kind].
  String get displayName => '${type.toString()} [${kind.label}]';
}

/// [Binder] implementation that records registrations without instantiating them.
///
/// Used by [ModuleBindingsAnalyzer] to introspect which types a module
/// registers during its `binds` and `exports` phases.
class RecordingBinder implements ExportableBinder {
  /// Create a recording binder with optional [imports] and [parent] scope.
  RecordingBinder({List<Binder> imports = const [], Binder? parent})
    : _imports = List.of(imports),
      _parent = parent;

  final List<Binder> _imports;
  final Binder? _parent;

  final List<DependencyRecord> _privateRecords = [];
  final List<DependencyRecord> _publicRecords = [];

  bool _isExportMode = false;
  bool _publicSealed = false;

  /// Return an unmodifiable list of privately registered dependencies.
  List<DependencyRecord> get privateDependencies =>
      List.unmodifiable(_privateRecords);

  /// Return an unmodifiable list of publicly exported dependencies.
  List<DependencyRecord> get publicDependencies =>
      List.unmodifiable(_publicRecords);

  @override
  void addImports(List<Binder> binders) {
    _imports.addAll(binders);
  }

  @override
  void disableExportMode() {
    _isExportMode = false;
  }

  @override
  void enableExportMode() {
    _isExportMode = true;
  }

  @override
  bool get isExportModeEnabled => _isExportMode;

  @override
  bool get isPublicScopeSealed => _publicSealed;

  @override
  void resetPublicScope() {
    _publicSealed = false;
  }

  @override
  void sealPublicScope() {
    _publicSealed = true;
  }

  @override
  void registerFactory<T extends Object>(T Function() factory) {
    _record(T, DependencyRegistrationKind.factory);
  }

  @override
  void registerLazySingleton<T extends Object>(T Function() factory) {
    _record(T, DependencyRegistrationKind.singleton);
  }

  @override
  void registerSingleton<T extends Object>(T instance) {
    _record(T, DependencyRegistrationKind.instance);
  }

  void _record(Type type, DependencyRegistrationKind kind) {
    final record = DependencyRecord(type, kind);
    if (_isExportMode) {
      if (_publicSealed) {
        throw ModuleConfigurationException(
          'Public scope is sealed. Cannot export dependency $type.',
        );
      }
      final alreadyExported =
          _publicRecords.indexWhere((r) => r.type == type) != -1;
      if (alreadyExported) {
        throw ModuleConfigurationException(
          'Dependency $type is already exported. Duplicate exports are not allowed.',
        );
      }
      _publicRecords.add(record);
      return;
    }

    final existingIndex = _privateRecords.indexWhere(
      (element) => element.type == type,
    );
    if (existingIndex >= 0) {
      _privateRecords[existingIndex] = record;
    } else {
      _privateRecords.add(record);
    }
  }

  @override
  T get<T extends Object>() {
    throw ModuleConfigurationException(
      'RecordingBinder cannot resolve $T during analysis. '
      'Avoid calling get() synchronously inside binds/exports when generating graphs.',
    );
  }

  @override
  T? tryGet<T extends Object>() => null;

  @override
  T parent<T extends Object>() {
    if (_parent == null) {
      throw DependencyNotFoundException(
        'No parent binder available for $T.',
        requestedType: T,
        lookupContext: 'parent scope',
      );
    }
    return _parent.get<T>();
  }

  @override
  T? tryParent<T extends Object>() => _parent?.tryGet<T>();

  bool _hasLocal(Type type) {
    return _privateRecords.any((record) => record.type == type) ||
        _publicRecords.any((record) => record.type == type);
  }

  @override
  bool contains(Type type) {
    if (_hasLocal(type)) return true;

    for (final binder in _imports) {
      if (binder is ExportableBinder) {
        if (binder.containsPublic(type)) {
          return true;
        }
        continue;
      }
      if (binder.contains(type)) {
        return true;
      }
    }

    if (_parent?.contains(type) == true) {
      return true;
    }

    return false;
  }

  @override
  T? tryGetPublic<T extends Object>() => null;

  @override
  bool containsPublic(Type type) {
    return _publicRecords.any((record) => record.type == type);
  }

  /// Return display names of all private dependency records.
  List<String> describePrivateDependencies() =>
      _privateRecords.map((e) => e.displayName).toList(growable: false);

  /// Return display names of all public dependency records.
  List<String> describePublicDependencies() =>
      _publicRecords.map((e) => e.displayName).toList(growable: false);
}
