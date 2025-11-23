import 'dart:async';
import 'package:modularity_contracts/modularity_contracts.dart';
import '../graph/graph_resolver.dart';
import '../di/simple_binder_factory.dart';
import '../di/simple_binder.dart';

/// Контроллер, управляющий жизненным циклом одного модуля.
class ModuleController {
  final Module module;
  final Binder binder;
  final BinderFactory _binderFactory; // Храним для создания импортов
  final StreamController<ModuleStatus> _statusController;
  final void Function(Binder)? overrides;
  final List<ModuleInterceptor> interceptors;
  
  /// Ссылка на контроллеры импортируемых модулей.
  final List<ModuleController> importedControllers = [];

  ModuleController(
    this.module, {
    Binder? binder,
    BinderFactory? binderFactory,
    this.overrides,
    this.interceptors = const [],
  })  : _statusController = StreamController<ModuleStatus>.broadcast(),
        binder = binder ?? (binderFactory ?? SimpleBinderFactory()).create(),
        _binderFactory = binderFactory ?? SimpleBinderFactory() {
    _statusController.add(ModuleStatus.initial);
  }

  Stream<ModuleStatus> get status => _statusController.stream;
  ModuleStatus _currentStatus = ModuleStatus.initial;
  ModuleStatus get currentStatus => _currentStatus;

  Object? _lastError;
  Object? get lastError => _lastError;

  /// Конфигурация модуля.
  void configure(dynamic args) {
    if (module is Configurable) {
      try {
        (module as Configurable).configure(args);
      } catch (e) {
        // Handle generic type mismatch gracefully or rethrow
        // If we pass wrong type to configure(T args), Dart throws TypeError.
        throw Exception(
          "Module ${module.runtimeType} failed to configure: "
          "Expected arguments of correct type for Configurable<T>.\n"
          "Error: $e"
        );
      }
    }
  }

  /// Запуск цикла инициализации.
  Future<void> initialize(
    Map<Type, ModuleController> globalModuleRegistry, {
    Set<Type>? resolutionStack,
  }) async {
    if (_currentStatus == ModuleStatus.loading || _currentStatus == ModuleStatus.loaded) {
      return;
    }

    // Interceptor: onInit
    for (var i in interceptors) i.onInit(module);

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
      );
      
      importedControllers.addAll(imports);
      final importBinders = imports.map((c) => c.binder).toList();

      // 2. Configure Binder with imports
      binder.addImports(importBinders);
      
      // 3. Validate Expects (Fail-Fast)
      for (final expectedType in module.expects) {
        // contains проверяет всю цепочку (Local + Imports + Parent)
        // Но на этом этапе Local пуст (binds еще не вызван).
        // Значит, мы проверяем Imports и Parent.
        if (!binder.contains(expectedType)) {
           throw Exception(
             "Module ${module.runtimeType} expects dependency of type '$expectedType', "
             "but it was not found in Parent Scope or Imports.\n"
             "Check if the parent module exports it or if it's correctly imported."
           );
        }
      }

      // 4. Binds (Private & Public)
      if (binder is SimpleBinder) (binder as SimpleBinder).disableExportMode();
      module.binds(binder);
      
      // Apply Overrides (Test)
      if (overrides != null) {
        overrides!(binder);
      }

      if (binder is SimpleBinder) (binder as SimpleBinder).enableExportMode();
      module.exports(binder);
      if (binder is SimpleBinder) (binder as SimpleBinder).disableExportMode();

      // 5. Async Init
      await module.onInit();

      _updateStatus(ModuleStatus.loaded);
      
      // Interceptor: onLoaded
      for (var i in interceptors) i.onLoaded(module);

    } catch (e) {
      _lastError = e;
      _updateStatus(ModuleStatus.error);
      
      // Interceptor: onError
      for (var i in interceptors) i.onError(module, e);
      
      rethrow;
    }
  }

  /// Hot Reload logic.
  void hotReload() {
    if (_currentStatus != ModuleStatus.loaded) return;
    
    // Перезапускаем binds, чтобы обновить фабрики.
    // Синглтоны в SimpleBinder сохранятся, если мы просто перезапишем поверх?
    // Нет, SimpleBinder перезапишет регистрацию и потеряет инстанс.
    // Для MVP мы просто вызываем хук и перезаписываем.
    // В будущем SimpleBinder должен поддерживать "updateFactoryOnly".
    
    if (binder is SimpleBinder) (binder as SimpleBinder).disableExportMode();
    module.binds(binder);
    if (binder is SimpleBinder) (binder as SimpleBinder).enableExportMode();
    module.exports(binder);
    
    // Хук пользователя
    module.hotReload(binder);
  }

  Future<void> dispose() async {
    _updateStatus(ModuleStatus.disposed);
    module.onDispose();
    if (binder is SimpleBinder) {
       (binder as SimpleBinder).dispose();
    }
    await _statusController.close();
    
    // Interceptor: onDispose
    for (var i in interceptors) i.onDispose(module);
  }

  void _updateStatus(ModuleStatus newStatus) {
    _currentStatus = newStatus;
    _statusController.add(newStatus);
  }
}
