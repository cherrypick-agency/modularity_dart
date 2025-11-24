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
    final currentStack = resolutionStack ?? {module.runtimeType};

    // 1. Подготавливаем все задачи (Futures), но запускаем их "параллельно"
    final futures = module.imports.map((importModule) async {
      final type = importModule.runtimeType;

      // Check Circular Dependency (Immediate Fail-Fast)
      if (currentStack.contains(type)) {
        throw Exception(
          'Circular dependency detected: ${currentStack.join(' -> ')} -> $type',
        );
      }

      // --- CRITICAL SECTION START (Synchronous) ---
      // Важно: Получение или создание контроллера должно быть атомарным,
      // чтобы параллельные ветки не создали дубликатов.
      // В Dart этот блок не прервется, пока нет await.
      ModuleController? controller = registry[type];

      if (controller == null) {
        controller = ModuleController(
          importModule,
          binderFactory: binderFactory,
          interceptors: interceptors,
        );
        registry[type] = controller;
      }
      // --- CRITICAL SECTION END ---

      // Ветка A и Ветка B получают свои КОПИИ стека.
      // Это позволяет безопасно проверять циклы в параллельных ветках.
      final newStack = {...currentStack, type};

      // Теперь безопасно вызываем await (yield execution)
      if (controller.currentStatus == ModuleStatus.initial) {
        await controller.initialize(registry, resolutionStack: newStack);
      } else if (controller.currentStatus == ModuleStatus.loading) {
        // Если модуль уже грузится (его пнула другая ветка), просто ждем.
        // Проверяем на цикл именно в ЭТОЙ ветке
        if (currentStack.contains(type)) {
           throw Exception(
            'Circular dependency detected (during loading): ${currentStack.join(' -> ')} -> $type'
          );
        }
        // "Smart Wait": Ждем пока другая ветка закончит работу
        await controller.status.firstWhere((s) => s == ModuleStatus.loaded);
      } else if (controller.currentStatus == ModuleStatus.error) {
        throw Exception("Dependent module $type failed to load: ${controller.lastError}");
      }

      return controller;
    });

    // 2. Ждем выполнения всех веток одновременно
    final resolvedControllers = await Future.wait(futures);

    return resolvedControllers;
  }
}
