import 'dart:async';

import 'package:modularity_contracts/modularity_contracts.dart';

import '../di/simple_binder_factory.dart';
import '../graph/graph_resolver.dart';
import '../graph/module_registry_key.dart';
import 'module_override_scope.dart';

/// Manage the full lifecycle of a single [Module]: resolution, initialisation,
/// hot reload, and disposal.
class ModuleController {
  /// Create a controller for [module] with optional DI configuration.
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

  /// Configure the module.
  void configure(dynamic args) {
    if (module is Configurable) {
      try {
        (module as Configurable).configure(args);
      } catch (e) {
        // Handle generic type mismatch gracefully or rethrow
        // If we pass wrong type to configure(T args), Dart throws TypeError.
        throw ModuleLifecycleException(
          'Module ${module.runtimeType} failed to configure: '
          'Expected arguments of correct type for Configurable<T>.\n'
          'Error: $e',
          moduleType: module.runtimeType,
        );
      }
    }
  }

  /// Start the initialization lifecycle.
  Future<void> initialize(
    Map<ModuleRegistryKey, ModuleController> globalModuleRegistry, {
    Set<Type>? resolutionStack,
  }) async {
    if (_currentStatus == ModuleStatus.loading ||
        _currentStatus == ModuleStatus.loaded) {
      return;
    }

    // Interceptor: onInit
    for (var i in interceptors) {
      i.onInit(module);
    }

    _updateStatus(ModuleStatus.loading);

    try {
      // 1. Resolve Imports via GraphResolver
      final resolver = GraphResolver();
      final imports = await resolver.resolveAndInitImports(
        module,
        globalModuleRegistry,
        _binderFactory,
        resolutionStack: resolutionStack,
        interceptors: interceptors,
        overrideScope: overrideScope,
      );

      _importedControllers.addAll(imports);
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
      final exportable = binder is ExportableBinder
          ? binder as ExportableBinder
          : null;
      exportable?.disableExportMode();
      module.binds(binder);

      _applyOverridesIfNeeded();

      exportable?.enableExportMode();
      module.exports(binder);
      exportable?.disableExportMode();
      exportable?.sealPublicScope();

      // 5. Async Init
      await module.onInit();

      _updateStatus(ModuleStatus.loaded);

      // Interceptor: onLoaded
      for (var i in interceptors) {
        i.onLoaded(module);
      }
    } catch (e) {
      _lastError = e;
      _updateStatus(ModuleStatus.error);

      // Interceptor: onError
      for (var i in interceptors) {
        i.onError(module, e);
      }

      rethrow;
    }
  }

  /// Hot Reload logic.
  void hotReload() {
    if (_currentStatus != ModuleStatus.loaded) return;

    // Re-run binds to update factories.
    // For MVP we simply call the hook and overwrite registrations.
    // In the future SimpleBinder should support "updateFactoryOnly".

    void rebind() {
      final exportable = binder is ExportableBinder
          ? binder as ExportableBinder
          : null;
      exportable?.resetPublicScope();
      exportable?.disableExportMode();
      module.binds(binder);
      _applyOverridesIfNeeded();
      exportable?.enableExportMode();
      module.exports(binder);
      exportable?.disableExportMode();
      exportable?.sealPublicScope();
    }

    final aware = _registrationAwareBinder;
    if (aware != null) {
      aware.runWithStrategy(RegistrationStrategy.preserveExisting, () {
        rebind();
      });
    } else {
      rebind();
    }

    // User hook
    module.hotReload(binder);
  }

  /// Dispose of the module, its [Binder], and close the status stream.
  Future<void> dispose() async {
    _updateStatus(ModuleStatus.disposed);

    // Interceptor: onDispose (before closing stream so listeners can still react)
    for (var i in interceptors) {
      i.onDispose(module);
    }

    module.onDispose();
    if (binder is DisposableBinder) {
      await (binder as DisposableBinder).dispose();
    }
    _importedControllers.clear();
    await _statusController.close();
  }

  void _updateStatus(ModuleStatus newStatus) {
    _currentStatus = newStatus;
    _statusController.add(newStatus);
  }

  void _applyOverridesIfNeeded() {
    final scope = overrideScope;
    scope?.selfOverrides?.call(binder);
  }
}
