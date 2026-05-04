import 'dart:async';

import 'package:modularity_contracts/modularity_contracts.dart';

import '../di/simple_binder_factory.dart';
import '../graph/graph_resolver.dart';
import '../graph/module_graph_node_key.dart';
import '../graph/module_registry_key.dart';
import 'module_override_scope.dart';

/// Manages the full lifecycle of a single [Module]: dependency resolution,
/// initialization, hot reload, and disposal.
///
/// The controller orchestrates the following sequence during [initialize]:
/// 1. Resolves and initializes all imported modules via [GraphResolver].
/// 2. Validates [Module.expects] against available scopes.
/// 3. Calls [Module.binds] (private scope) and [Module.exports] (public scope).
/// 4. Applies any [overrides] to the binder.
/// 5. Calls [Module.onInit] for async setup.
///
/// ```dart
/// final controller = ModuleController(AppModule());
/// await controller.initialize({});
///
/// // Access dependencies:
/// final service = controller.binder.get<MyService>();
///
/// // Dispose when done:
/// await controller.dispose();
/// ```
///
/// See also:
/// - [Module] for the lifecycle hooks.
/// - `GraphResolver` for the import resolution algorithm.
/// - [ModuleOverrideScope] for hierarchical dependency overrides.
class ModuleController {
  /// Creates a controller for [module] with optional DI configuration.
  ///
  /// When neither [binder] nor [binderFactory] is supplied, a default
  /// [SimpleBinderFactory] is used.
  ModuleController(
    this.module, {
    Binder? binder,
    BinderFactory? binderFactory,
    this.overrides,
    ModuleOverrideScope? overrideScopeTree,
    this.interceptors = const [],
  }) : _statusController = StreamController<ModuleStatus>.broadcast(),
       binder = binder ?? (binderFactory ?? SimpleBinderFactory()).create(),
       _binderFactory = binderFactory ?? SimpleBinderFactory(),
       overrideScope =
           overrideScopeTree?.withAdditionalOverride(overrides) ??
           (overrides != null
               ? ModuleOverrideScope(selfOverrides: overrides)
               : overrideScopeTree) {
    _statusController.add(ModuleStatus.initial);
  }

  /// The [Module] whose lifecycle this controller manages.
  final Module module;

  /// The [Binder] that holds all dependency registrations for [module].
  final Binder binder;
  final BinderFactory _binderFactory;
  final StreamController<ModuleStatus> _statusController;

  /// Optional callback applied to the [Binder] after binds/exports to override
  /// registrations (e.g. for testing or feature flags).
  final void Function(Binder)? overrides;

  /// Hierarchical override scope propagated to imported modules.
  final ModuleOverrideScope? overrideScope;

  /// Ordered list of [ModuleInterceptor]s notified at each lifecycle event.
  final List<ModuleInterceptor> interceptors;

  /// References to the controllers of imported modules.
  List<ModuleController> get importedControllers =>
      List.unmodifiable(_importedControllers);
  final List<ModuleController> _importedControllers = [];
  bool _importsRetained = false;
  int _dependentCount = 0;
  Future<void>? _initializeFuture;
  Future<void>? _disposeFuture;
  bool _lifecycleStarted = false;

  /// Broadcast stream of [ModuleStatus] transitions.
  Stream<ModuleStatus> get status => _statusController.stream;
  ModuleStatus _currentStatus = ModuleStatus.initial;

  /// Return the most recent [ModuleStatus] of this controller.
  ModuleStatus get currentStatus => _currentStatus;

  RegistrationAwareBinder? get _registrationAwareBinder =>
      binder is RegistrationAwareBinder
      ? binder as RegistrationAwareBinder
      : null;

  Object? _lastError;

  /// Return the error captured during the last failed [initialize] call, or
  /// `null` if no error occurred.
  Object? get lastError => _lastError;

  /// Passes [args] to the module's [Configurable.configure] method.
  ///
  /// Throws [ModuleLifecycleException] if the module implements [Configurable]
  /// but the argument type does not match.
  void configure(dynamic args) {
    if (_currentStatus != ModuleStatus.initial) {
      throw ModuleLifecycleException(
        'Module ${module.runtimeType} cannot be configured after initialization has started.',
        moduleType: module.runtimeType,
        state: _currentStatus,
      );
    }

    if (module is Configurable) {
      try {
        (module as Configurable).configure(args);
      } catch (error) {
        // Handle generic type mismatch gracefully or rethrow
        // If we pass wrong type to configure(T args), Dart throws TypeError.
        final exception = ModuleLifecycleException(
          'Module ${module.runtimeType} failed to configure: '
          'Expected arguments of correct type for Configurable<T>.\n'
          'Error: $error',
          moduleType: module.runtimeType,
        );
        _lastError = exception;
        _updateStatus(ModuleStatus.error);
        throw exception;
      }
    }
  }

  /// Runs the full initialization lifecycle for this module.
  ///
  /// Uses [globalModuleRegistry] to deduplicate module controllers across
  /// concurrent import branches. Pass [graphResolutionStack] for cycle
  /// detection when resolving nested imports.
  ///
  /// Throws [CircularDependencyException], [ModuleConfigurationException],
  /// or [ModuleLifecycleException] on failure.
  Future<void> initialize(
    Map<ModuleRegistryKey, ModuleController> globalModuleRegistry, {

    /// Legacy type-only cycle stack. Prefer [graphResolutionStack].
    Set<Type>? resolutionStack,
    Set<ModuleGraphNodeKey>? graphResolutionStack,
  }) {
    switch (_currentStatus) {
      case ModuleStatus.initial:
        _initializeFuture ??= _initializeInternal(
          globalModuleRegistry,
          resolutionStack: resolutionStack,
          graphResolutionStack: graphResolutionStack,
        );
        return _initializeFuture!;
      case ModuleStatus.loading:
        return _initializeFuture ?? Future<void>.value();
      case ModuleStatus.loaded:
        return Future<void>.value();
      case ModuleStatus.error:
        return Future<void>.error(
          ModuleLifecycleException(
            'Module ${module.runtimeType} failed to initialize previously. '
            'Create a new ModuleController to retry initialization.',
            moduleType: module.runtimeType,
            state: ModuleStatus.error,
          ),
        );
      case ModuleStatus.disposed:
        return Future<void>.error(
          ModuleLifecycleException(
            'Module ${module.runtimeType} has been disposed and cannot be initialized again.',
            moduleType: module.runtimeType,
            state: ModuleStatus.disposed,
          ),
        );
    }
  }

  Future<void> _initializeInternal(
    Map<ModuleRegistryKey, ModuleController> globalModuleRegistry, {
    Set<Type>? resolutionStack,
    Set<ModuleGraphNodeKey>? graphResolutionStack,
  }) async {
    _lifecycleStarted = true;
    _updateStatus(ModuleStatus.loading);

    try {
      // Interceptor: onInit
      for (final interceptor in interceptors) {
        interceptor.onInit(module);
      }

      // 1. Resolve Imports via GraphResolver
      final resolver = GraphResolver();
      final imports = await resolver.resolveAndInitImports(
        module,
        globalModuleRegistry,
        _binderFactory,
        resolutionStack: resolutionStack,
        graphResolutionStack: graphResolutionStack,
        interceptors: interceptors,
        overrideScope: overrideScope,
      );

      _retainImports(imports);
      final importBinders = imports.map((c) => c.binder).toList();

      // 2. Configure Binder with imports
      binder.addImports(importBinders);

      // 3. Validate Expects (Fail-Fast)
      for (final expectedType in module.expects) {
        // contains checks the entire chain (Local + Imports + Parent).
        // At this stage Local is empty (binds hasn't been called yet),
        // so we're effectively checking Imports and Parent.
        if (!binder.contains(expectedType)) {
          throw ModuleConfigurationException(
            "Module ${module.runtimeType} expects dependency of type '$expectedType', "
            'but it was not found in Parent Scope or Imports.\n'
            "Check if the parent module exports it or if it's correctly imported.",
            moduleType: module.runtimeType,
          );
        }
      }

      // 4. Binds (Private & Public)
      _runBindsAndExports();

      // 5. Async Init
      await module.onInit();

      _updateStatus(ModuleStatus.loaded);

      // Interceptor: onLoaded
      for (final interceptor in interceptors) {
        interceptor.onLoaded(module);
      }
    } catch (error, stackTrace) {
      _lastError = error;
      _updateStatus(ModuleStatus.error);

      Object? firstError = error;
      StackTrace? firstStackTrace = stackTrace;

      void preserveFirstError(
        Object cleanupError,
        StackTrace cleanupStackTrace,
      ) {
        firstError ??= cleanupError;
        firstStackTrace ??= cleanupStackTrace;
      }

      try {
        await _releaseRetainedImports(<ModuleController>{this});
      } catch (cleanupError, cleanupStackTrace) {
        preserveFirstError(cleanupError, cleanupStackTrace);
      }

      // Interceptor: onError
      for (final interceptor in interceptors) {
        try {
          interceptor.onError(module, error);
        } catch (interceptorError, interceptorStackTrace) {
          preserveFirstError(interceptorError, interceptorStackTrace);
        }
      }

      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  /// Re-runs [Module.binds] and [Module.exports] under
  /// [RegistrationStrategy.preserveExisting] to refresh factory closures
  /// without losing singleton state.
  ///
  /// No-op if the module is not in the [ModuleStatus.loaded] state.
  void hotReload() {
    if (_currentStatus != ModuleStatus.loaded) return;

    // Re-run binds to update factories.
    // For MVP we simply call the hook and overwrite registrations.
    // In the future SimpleBinder should support "updateFactoryOnly".

    final aware = _registrationAwareBinder;
    if (aware != null) {
      aware.runWithStrategy(RegistrationStrategy.preserveExisting, () {
        _runBindsAndExports(resetPublicScope: true);
      });
    } else {
      _runBindsAndExports(resetPublicScope: true);
    }

    // User hook
    module.hotReload(binder);
  }

  /// Disposes the module, its [Binder], and closes the status stream.
  ///
  /// Calls [Module.onDispose], then [DisposableBinder.dispose] if the
  /// binder supports it, and finally closes the [status] stream.
  Future<void> dispose() {
    return _disposeFuture ??= _disposeInternal(<ModuleController>{});
  }

  Future<void> _disposeInternal(Set<ModuleController> visited) async {
    if (_currentStatus == ModuleStatus.disposed || !visited.add(this)) {
      return;
    }

    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> guard(FutureOr<void> Function() body) async {
      try {
        await Future.sync(body);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (_currentStatus == ModuleStatus.loading && _initializeFuture != null) {
      await guard(() => _initializeFuture!);
    }

    if (_currentStatus == ModuleStatus.disposed) {
      return;
    }

    _updateStatus(ModuleStatus.disposed);

    // Interceptor: onDispose (before closing stream so listeners can still react).
    for (final interceptor in interceptors) {
      await guard(() => interceptor.onDispose(module));
    }

    if (_lifecycleStarted) {
      await guard(module.onDispose);
    }
    if (binder is DisposableBinder) {
      final disposableBinder = binder as DisposableBinder;
      await guard(disposableBinder.dispose);
    }

    await guard(() => _releaseRetainedImports(visited));

    if (!_statusController.isClosed) {
      await _statusController.close();
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  void _retainImports(List<ModuleController> imports) {
    if (imports.isEmpty) return;

    _importedControllers.addAll(imports);

    for (final controller in <ModuleController>{...imports}) {
      controller._dependentCount++;
    }

    _importsRetained = true;
  }

  Future<void> _releaseRetainedImports(Set<ModuleController> visited) async {
    if (!_importsRetained) return;

    final imports = <ModuleController>{..._importedControllers}.toList();
    _importedControllers.clear();
    _importsRetained = false;

    for (final controller in imports.reversed) {
      await controller._releaseDependent(visited);
    }
  }

  Future<void> _releaseDependent(Set<ModuleController> visited) async {
    if (_dependentCount > 0) {
      _dependentCount--;
    }

    if (_dependentCount > 0) return;

    await (_disposeFuture ??= _disposeInternal(visited));
  }

  void _updateStatus(ModuleStatus newStatus) {
    _currentStatus = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  void _runBindsAndExports({bool resetPublicScope = false}) {
    final exportable = binder is ExportableBinder
        ? binder as ExportableBinder
        : null;

    if (resetPublicScope) {
      exportable?.resetPublicScope();
    }

    exportable?.disableExportMode();
    module.binds(binder);
    _applyOverridesIfNeeded();

    try {
      exportable?.enableExportMode();
      module.exports(binder);
    } finally {
      exportable?.disableExportMode();
    }

    exportable?.sealPublicScope();
  }

  void _applyOverridesIfNeeded() {
    final scope = overrideScope;
    scope?.selfOverrides?.call(binder);
  }
}
