import 'package:flutter/widgets.dart';
import 'package:modularity_core/modularity_core.dart';

/// Inherited widget that exposes a [ModuleController] and its [Binder] to
/// descendant widgets.
///
/// Typically inserted by [ModuleScope]; consumers obtain the [Binder] via
/// [ModuleProvider.of] or retrieve the typed [Module] via
/// [ModuleProvider.moduleOf].
///
/// ## Resolving Dependencies
///
/// ```dart
/// final binder = ModuleProvider.of(context);
/// final service = binder.get<MyService>();
/// ```
///
/// ## Accessing the Module Instance
///
/// ```dart
/// final module = ModuleProvider.moduleOf<AuthModule>(context);
/// ```
///
/// See also:
/// - [ModuleScope] which creates and provides this widget.
/// - [ModularityRoot] for top-level DI configuration.
class ModuleProvider extends InheritedWidget {
  /// Create a [ModuleProvider] that exposes [controller] to [child].
  const ModuleProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  /// Controller that owns the DI [Binder] and the [Module] lifecycle.
  final ModuleController controller;

  @override
  bool updateShouldNotify(ModuleProvider oldWidget) {
    return controller != oldWidget.controller;
  }

  /// Retrieves the [Binder] from the nearest module.
  /// Used to obtain dependencies manually:
  /// `ModuleProvider.of(context).get<Service>()`
  /// `ModuleProvider.of(context).parent<Service>()`
  static Binder of(BuildContext context, {bool listen = true}) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<ModuleProvider>()
        : context.getInheritedWidgetOfExactType<ModuleProvider>();

    if (provider == null) {
      throw ModuleConfigurationException(
        'ModuleProvider not found in context.',
      );
    }
    return provider.controller.binder;
  }

  /// Retrieves the module of type [M] from the context.
  static M moduleOf<M extends Module>(
    BuildContext context, {
    bool listen = true,
  }) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<ModuleProvider>()
        : context.getInheritedWidgetOfExactType<ModuleProvider>();

    if (provider == null) {
      throw ModuleConfigurationException(
        'ModuleProvider not found in context.',
      );
    }

    if (provider.controller.module is! M) {
      throw ModuleConfigurationException(
        'Nearest module is ${provider.controller.module.runtimeType}, but expected $M.',
      );
    }

    return provider.controller.module as M;
  }
}
