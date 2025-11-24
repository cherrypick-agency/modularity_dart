import 'dart:async';
import 'binder.dart';
import 'configurable.dart';

/// Статусы жизненного цикла модуля
enum ModuleStatus {
  /// Модуль только создан, ничего не происходит
  initial,

  /// Модуль в процессе инициализации (выполняется onInit)
  loading,

  /// Модуль успешно инициализирован и готов к работе
  loaded,

  /// Произошла ошибка при инициализации
  error,

  /// Модуль уничтожен
  disposed,
}

/// Базовый контракт Модуля.
/// Модуль - это единица логики, имеющая свой жизненный цикл и зависимости.
abstract class Module {
  /// Список модулей, от которых зависит этот модуль.
  /// Они будут инициализированы ДО старта этого модуля.
  List<Module> get imports => [];

  /// List of structural sub-features that compose this module.
  /// Used for static analysis and visualization ONLY.
  /// Modules listed here should use the [Configurable] interface for runtime parameters
  /// instead of constructor arguments, allowing for clean static instantiation.
  List<Module> get submodules => [];

  /// Список типов, которые ОБЯЗАН предоставить родительский скоуп.
  /// Проверяется при старте. Если типа нет — инициализация падает с ошибкой.
  List<Type> get expects => [];

  /// Регистрация зависимостей, доступных ТОЛЬКО внутри этого модуля (Private).
  void binds(Binder i);

  /// Регистрация зависимостей, которые этот модуль предоставляет внешнему миру (Public).
  /// Эти зависимости будут доступны тем модулям, которые импортируют текущий.
  void exports(Binder i) {}

  /// Асинхронная инициализация.
  /// Вызывается после того, как все [imports] перешли в статус [ModuleStatus.loaded],
  /// и после выполнения [binds] и [exports].
  Future<void> onInit() async {}

  /// Освобождение ресурсов.
  /// Вызывается при уничтожении модуля.
  void onDispose() {}

  /// Хук для Hot Reload.
  /// Позволяет обновить фабрики без потери состояния синглтонов.
  void hotReload(Binder i) {}
}
