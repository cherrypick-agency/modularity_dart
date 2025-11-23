# **Architecture Design Document (RFC): Modular Framework**

Version: 1.0.3
Status: Released

Philosophy: "Glue, not Magic". Строгость в DI и Lifecycle, гибкость в UI и Routing.

## **1. Глоссарий и Основные Абстракции**

- **Module (Модуль):** Класс конфигурации (DTO/Composition Root). Определяет граф зависимостей (imports), биндинги (binds) и требования (expects). **Не хранит состояние.**
- **ModuleController:** Движок модуля. Управляет жизненным циклом (State Machine: initial -> loading -> loaded), валидирует зависимости и выполняет инициализацию.
- **Binder:** Абстракция DI контейнера. Поддерживает scopes (parent/child).
- **ModuleScope:** Виджет, связывающий ModuleController с UI.
- **Retention Policy:** Стратегия управления памятью. Использует **RouteObserver** для надежного dispose.

## **2. Module Contract**

```dart
abstract class Module {
  /// Список модулей, которые должны быть инициализированы ДО этого модуля.
  List<Module> get imports => [];

  /// Список типов, которые ОБЯЗАН предоставить родительский скоуп.
  /// Если зависимость не найдена, инициализация упадет с ошибкой.
  List<Type> get expects => [];

  void binds(Binder i);
  void exports(Binder i) {}

  Future<void> onInit() async {}
  void onDispose() {}
  
  /// Хук для Hot Reload (DX).
  /// Позволяет обновить фабрики без потери состояния синглтонов.
  void hotReload(Binder i) {}
}
```

## **3. Dependency Injection & Scoping**

Фреймворк поддерживает дерево скоупов:
1. **Local:** Зависимости текущего модуля.
2. **Imports:** Публичные зависимости импортированных модулей.
3. **Parent:** Зависимости родительского модуля (вверх по дереву виджетов).

```dart
// Поиск: Local -> Imports -> Parent -> Error
i.get<Service>(); 

// Явный запрос к родителю
i.parent<Service>();
```

## **4. State Management Integration**

Modularity агностичен к State Management. Он управляет жизненным циклом модулей, а SM управляет состоянием UI.

### **Bloc / Cubit**
Регистрируйте Cubit в `binds` и используйте `BlocProvider` в виджете.

```dart
// 1. Module
class CounterModule extends Module {
  @override
  void binds(Binder i) {
    i.factory<CounterCubit>(() => CounterCubit());
  }
}

// 2. Widget
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Resolve from Module (listen: false is important for create)
      create: (context) => ModuleProvider.of(context, listen: false).get<CounterCubit>(),
      child: CounterView(),
    );
  }
}
```

### **Riverpod**
Используйте `ProviderScope` с `overrides` для внедрения зависимостей из модуля.

```dart
// 1. Riverpod Provider (Abstract)
final authProvider = Provider<AuthService>((ref) => throw UnimplementedError());

// 2. Widget
class RiverpodPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = ModuleProvider.of(context).get<AuthService>();
    
    return ProviderScope(
      overrides: [
        authProvider.overrideWithValue(authService),
      ],
      child: RiverpodView(),
    );
  }
}
```

## **5. Retention Policy & Navigation**

Мы используем **RouteBound Strategy** по умолчанию.
Для корректной работы необходимо подключить `Modularity.observer`.

```dart
// main.dart
MaterialApp(
  navigatorObservers: [Modularity.observer],
  // ...
);
```

- **Push:** Модуль создается.
- **Cover (Push over):** Модуль жив (так как экран в стеке).
- **Pop:** Модуль уничтожается (dispose).
- **Fallback:** Если observer не подключен, модуль уничтожается при unmount виджета (Strict Strategy).

## **6. Testing Strategy**

### **Unit Testing (Headless)**
Используйте `testModule` из `modularity_test` для тестирования логики модуля в изоляции.

```dart
await testModule(
  MyModule(),
  (module, binder) async {
    // Verify bindings
    expect(binder.get<MyService>(), isNotNull);
  }
);
```

### **Widget Testing**
Для тестирования отдельных экранов используется `overrides`.

```dart
ModuleScope(
  module: ProfileModule(),
  // Подмена зависимостей ПЕРЕД инициализацией
  overrides: (binder) {
    binder.singleton<Api>(() => MockApi());
  },
  child: ProfilePage(),
)
```

## **7. Routing Integration**

Modularity легко интегрируется с популярными пакетами роутинга. Главное требование — подключить `Modularity.observer`.

### **GoRouter**

```dart
final router = GoRouter(
  observers: [Modularity.observer],
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => ModuleScope(
        module: HomeModule(),
        child: HomePage(),
      ),
    ),
  ],
);
```

### **AutoRoute**

```dart
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: HomeRoute.page, path: '/home'),
  ];
}

// main.dart
MaterialApp.router(
  routerConfig: appRouter.config(
    navigatorObservers: () => [Modularity.observer],
  ),
);

// HomePage (Inside ModuleScope)
@RoutePage()
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: HomeModule(),
      child: Scaffold(...),
    );
  }
}
```

## **8. Developer Tools (CLI)**

Используйте `modularity_cli` для визуализации графа зависимостей.

```bash
# Create a script in tool/visualize.dart
dart tool/visualize.dart
```

Это сгенерирует HTML-файл с интерактивным графом модулей.
