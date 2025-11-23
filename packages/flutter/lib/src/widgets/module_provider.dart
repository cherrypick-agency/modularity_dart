import 'package:flutter/widgets.dart';
import 'package:modularity_core/modularity_core.dart';

class ModuleProvider extends InheritedWidget {
  final ModuleController controller;

  const ModuleProvider({
    Key? key,
    required this.controller,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  bool updateShouldNotify(ModuleProvider oldWidget) {
    return controller != oldWidget.controller;
  }

  /// Получает [Binder] из ближайшего модуля.
  /// Используется для получения зависимостей вручную:
  /// `ModuleProvider.of(context).get<Service>()`
  /// `ModuleProvider.of(context).parent<Service>()`
  static Binder of(BuildContext context, {bool listen = true}) {
    final provider = listen 
        ? context.dependOnInheritedWidgetOfExactType<ModuleProvider>()
        : context.getInheritedWidgetOfExactType<ModuleProvider>();

    if (provider == null) {
      throw Exception('ModuleProvider not found in context');
    }
    return provider.controller.binder;
  }
  
  /// Получает сам модуль типа [M] из контекста.
  static M moduleOf<M extends Module>(BuildContext context, {bool listen = true}) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<ModuleProvider>()
        : context.getInheritedWidgetOfExactType<ModuleProvider>();

    if (provider == null) {
      throw Exception('ModuleProvider not found in context');
    }
    
    if (provider.controller.module is! M) {
       throw Exception('Nearest module is ${provider.controller.module.runtimeType}, but expected $M');
    }
    
    return provider.controller.module as M;
  }
}
