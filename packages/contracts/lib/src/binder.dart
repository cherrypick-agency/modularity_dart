/// Интерфейс для регистрации зависимостей.
/// Абстрагирует конкретную реализацию DI (будь то GetIt, карта или что-то еще).
abstract class Binder {
  /// Алиас для [registerLazySingleton].
  /// Регистрирует синглтон. Создается один раз при первом запросе (lazy).
  void singleton<T extends Object>(T Function() factory);

  /// Регистрирует ленивый синглтон.
  /// Создается один раз при первом запросе.
  /// Аналог [singleton] в Binder, переименован для соответствия GetIt API.
  void registerLazySingleton<T extends Object>(T Function() factory);

  /// Алиас для [registerFactory].
  /// Регистрирует фабрику. Создается каждый раз при запросе.
  void factory<T extends Object>(T Function() factory);

  /// Регистрирует фабрику.
  /// Создается каждый раз при запросе.
  /// Аналог [factory] в Binder, переименован для соответствия GetIt API.
  void registerFactory<T extends Object>(T Function() factory);

  /// Регистрирует уже созданный инстанс (Eager Singleton).
  /// Заменяет старые методы [instance] и [eagerSingleton].
  void registerSingleton<T extends Object>(T instance);

  /// Получает зависимость типа [T].
  /// [moduleId] - опциональный идентификатор модуля, который запрашивает зависимость (для скоупинга).
  T get<T extends Object>();

  /// Пытается получить зависимость, возвращает null если не найдено.
  T? tryGet<T extends Object>();

  /// Получает зависимость из родительского скоупа (Explicit Parent Lookup).
  T parent<T extends Object>();

  /// Пытается получить зависимость из родительского скоупа.
  T? tryParent<T extends Object>();

  /// Добавляет внешние биндеры (импорты), в которых нужно искать зависимости.
  void addImports(List<Binder> binders);

  /// Проверяет наличие зависимостей указанного типа (включая родителей и импорты).
  bool contains(Type type);
}

/// Расширенный интерфейс для Binder, поддерживающий экспорт зависимостей.
abstract class ExportableBinder implements Binder {
  /// Включает режим экспорта (регистрация в публичный скоуп).
  void enableExportMode();

  /// Выключает режим экспорта (регистрация в приватный скоуп).
  void disableExportMode();

  /// Пытается получить зависимость ТОЛЬКО из публичного скоупа.
  T? tryGetPublic<T extends Object>();

  /// Проверяет наличие публичной зависимости.
  bool containsPublic(Type type);
}
