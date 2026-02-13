/// Contracts (interfaces) for the Modularity dependency-injection framework.
///
/// This library defines the core abstractions that every Modularity package
/// depends on: [Binder], [Module], [BinderFactory], [Configurable],
/// [ModuleInterceptor], and the exception hierarchy.
///
/// Concrete implementations live in separate packages such as
/// `modularity_core` and `modularity_injectable`.
///
/// ```dart
/// import 'package:modularity_contracts/modularity_contracts.dart';
///
/// class AuthModule extends Module {
///   @override
///   void binds(Binder i) {
///     i.registerLazySingleton<AuthService>(() => AuthServiceImpl());
///   }
/// }
/// ```
library modularity_contracts;

export 'src/binder.dart';
export 'src/binder_factory.dart';
export 'src/configurable.dart';
export 'src/exceptions.dart';
export 'src/logger.dart';
export 'src/module.dart';
export 'src/module_interceptor.dart';
export 'src/retention_policy.dart';
