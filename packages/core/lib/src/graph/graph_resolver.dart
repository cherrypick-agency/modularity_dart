import 'dart:async';
import 'package:modularity_contracts/modularity_contracts.dart';
import '../engine/module_controller.dart';

/// Сервис для разрешения зависимостей модуля (Imports).
/// Отвечает за поиск, создание и инициализацию импортируемых модулей.
class GraphResolver {
  /// Рекурсивно разрешает и инициализирует импорты.
  /// Возвращает список контроллеров зависимостей.
  Future<List<ModuleController>> resolveAndInitImports(
    Module module,
    Map<Type, ModuleController> registry,
    BinderFactory binderFactory, {
    Set<Type>? resolutionStack,
    List<ModuleInterceptor> interceptors = const [],
  }) async {
    final List<ModuleController> resolvedControllers = [];
    final currentStack = resolutionStack ?? {module.runtimeType};

    for (final importModule in module.imports) {
      final type = importModule.runtimeType;
      
      // Circular Dependency Check
      if (currentStack.contains(type)) {
        throw Exception(
          'Circular dependency detected: ${currentStack.join(' -> ')} -> $type'
        );
      }

      ModuleController? controller = registry[type];

      // 1. Если контроллера нет - создаем (Lazy creation)
      if (controller == null) {
        controller = ModuleController(
          importModule, 
          binderFactory: binderFactory,
          interceptors: interceptors,
        );
        registry[type] = controller;
      }

      // 2. Если модуль еще не инициализирован - запускаем процесс
      if (controller.currentStatus == ModuleStatus.initial) {
        // Добавляем текущий модуль в стек и рекурсивно инициализируем зависимость
        final newStack = {...currentStack, type};
        
        // Передаем стек для проверки циклов вглубь
        await controller.initialize(registry, resolutionStack: newStack);
        
      } else if (controller.currentStatus == ModuleStatus.loading) {
        // Если модуль загружается, это может быть цикл, если он в нашем стеке.
        if (currentStack.contains(type)) {
           throw Exception(
            'Circular dependency detected (during loading): ${currentStack.join(' -> ')} -> $type'
          );
        }
        // Иначе это просто параллельная загрузка, ждем.
        await controller.status.firstWhere((s) => s == ModuleStatus.loaded);
      } else if (controller.currentStatus == ModuleStatus.error) {
         throw Exception("Dependent module $type failed to load: ${controller.lastError}");
      }

      resolvedControllers.add(controller);
    }

    return resolvedControllers;
  }
}
