/// Flutter integration for the Modularity dependency injection framework.
///
/// Provides widgets that manage [Module] lifecycles within the Flutter widget
/// tree, including automatic initialization, error handling, and configurable
/// retention policies.
///
/// ## Getting Started
///
/// Wrap your app with [ModularityRoot] and place [ModuleScope] widgets where
/// modules are needed:
///
/// ```dart
/// ModularityRoot(
///   child: MaterialApp(
///     navigatorObservers: [Modularity.observer],
///     home: ModuleScope<HomeModule>(
///       module: HomeModule(),
///       child: const HomePage(),
///     ),
///   ),
/// )
/// ```
///
/// Access registered dependencies via [ModuleProvider]:
///
/// ```dart
/// final service = ModuleProvider.of(context).get<MyService>();
/// ```
///
/// ## Key Classes
///
/// - [ModularityRoot] -- root inherited widget providing DI configuration.
/// - [ModuleScope] -- manages a single module's lifecycle with retention.
/// - [ModuleProvider] -- exposes a module's [Binder] to descendants.
/// - [Modularity] -- global configuration (observer, interceptors, logging).
/// - [ModuleRetainer] -- cache for controllers with KeepAlive policy.
library modularity_flutter;

export 'package:modularity_core/modularity_core.dart';

export 'src/modularity.dart'
    show Modularity, ModuleLifecycleEvent, ModuleLifecycleLogger;
export 'src/retention/module_retainer.dart'
    show ModuleRetainer, ModuleRetainerEntrySnapshot;
export 'src/widgets/modularity_root.dart';
export 'src/widgets/module_provider.dart';
export 'src/widgets/module_scope.dart';
