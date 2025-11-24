import 'package:flutter/widgets.dart';
import 'package:modularity_core/modularity_core.dart';

/// Корневой виджет фреймворка.
/// Хранит глобальный реестр активных модулей и конфигурацию DI.
class ModularityRoot extends InheritedWidget {
  final Map<Type, ModuleController> _registry = {};
  final BinderFactory binderFactory;
  final WidgetBuilder? defaultLoadingBuilder;
  final Widget Function(BuildContext, Object? error, VoidCallback retry)?
      defaultErrorBuilder;

  ModularityRoot({
    Key? key,
    required Widget child,
    BinderFactory? binderFactory,
    this.defaultLoadingBuilder,
    this.defaultErrorBuilder,
  })  : binderFactory = binderFactory ?? SimpleBinderFactory(),
        super(key: key, child: child);

  @override
  bool updateShouldNotify(ModularityRoot oldWidget) =>
      binderFactory != oldWidget.binderFactory ||
      defaultLoadingBuilder != oldWidget.defaultLoadingBuilder ||
      defaultErrorBuilder != oldWidget.defaultErrorBuilder;

  static ModularityRoot of(BuildContext context) {
    final root = context.dependOnInheritedWidgetOfExactType<ModularityRoot>();
    if (root == null) {
      throw Exception(
          'ModularityRoot not found. Please wrap your app in ModularityRoot (or ModularApp).');
    }
    return root;
  }

  static Map<Type, ModuleController> registryOf(BuildContext context) =>
      of(context)._registry;
  static BinderFactory binderFactoryOf(BuildContext context) =>
      of(context).binderFactory;

  static WidgetBuilder? defaultLoadingBuilderOf(BuildContext context) =>
      of(context).defaultLoadingBuilder;
  static Widget Function(BuildContext, Object?, VoidCallback)?
      defaultErrorBuilderOf(BuildContext context) =>
          of(context).defaultErrorBuilder;
}
