/// Standalone GetIt adapter for the Modularity dependency injection framework.
///
/// Provides a [GetItBinder] backed by a single [GetIt] instance with support
/// for [RegistrationAwareBinder] strategies (replace vs preserve-existing)
/// and a [GetItBinderFactory] for use with [ModularityRoot].
///
/// ## Usage
///
/// ```dart
/// ModularityRoot(
///   binderFactory: const GetItBinderFactory(),
///   child: const MyApp(),
/// )
/// ```
///
/// For `injectable` integration, use the `modularity_injectable` package
/// instead, which manages separate private/public containers.
library modularity_get_it;

export 'src/get_it_binder.dart';
export 'src/get_it_binder_factory.dart';
