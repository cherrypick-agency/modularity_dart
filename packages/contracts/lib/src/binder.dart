/// Интерфейс для регистрации зависимостей.
/// Абстрагирует конкретную реализацию DI (будь то GetIt, карта или что-то еще).
abstract class Binder {
  /// Регистрирует синглтон. Создается один раз при первом запросе (lazy)
  /// или сразу (в зависимости от реализации, но по стандарту lazy).
  void singleton<T extends Object>(T Function() factory);

  /// Регистрирует "жадный" синглтон.
  /// Создается СРАЗУ же в момент вызова этого метода.
  void eagerSingleton<T extends Object>(T Function() factory);

  /// Регистрирует фабрику. Создается каждый раз при запросе.
  void factory<T extends Object>(T Function() factory);

  /// Регистрирует уже созданный инстанс.
  void instance<T extends Object>(T instance);

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
