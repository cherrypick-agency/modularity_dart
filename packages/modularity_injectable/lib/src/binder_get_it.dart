import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:modularity_contracts/modularity_contracts.dart' as contracts;

/// [GetIt] wrapper that falls back to Modularity's [Binder] chain on resolve.
///
/// This is the integration layer between `injectable`-generated factories and
/// the Modularity DI system. When injectable factories call
/// `getIt.get<T>()`, this wrapper resolves through:
///
/// 1. Local [GetIt] scope (the [primary] container).
/// 2. Modularity [Binder] chain (imports -> parent).
///
/// This allows injectable-registered types to depend on types from imported
/// or parent modules without explicit cross-registration.
///
/// Named registrations (`instanceName`) and factory params are delegated to
/// the underlying [GetIt] only, as the Modularity [Binder] interface does
/// not support those concepts.
///
/// See also:
/// - [ModularityInjectableBridge] which creates [BinderGetIt] instances.
class BinderGetIt implements GetIt {
  /// Create a [BinderGetIt] wrapping the given [primary] GetIt instance
  /// and falling back to [binder] for unresolved lookups.
  BinderGetIt({required GetIt primary, required contracts.Binder binder})
    : _primary = primary,
      _binder = binder;

  final GetIt _primary;
  final contracts.Binder _binder;

  @override
  bool get allowReassignment => _primary.allowReassignment;

  @override
  set allowReassignment(bool value) => _primary.allowReassignment = value;

  @override
  T call<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) => get<T>(
    instanceName: instanceName,
    param1: param1,
    param2: param2,
    type: type,
  );

  @override
  T get<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    // If caller uses GetIt-only features (named registrations / params),
    // delegate without trying Binder fallbacks.
    final usesAdvancedGetItFeatures =
        instanceName != null ||
        param1 != null ||
        param2 != null ||
        type != null;
    if (usesAdvancedGetItFeatures) {
      return _primary.get<T>(
        instanceName: instanceName,
        param1: param1,
        param2: param2,
        type: type,
      );
    }

    if (_primary.isRegistered<T>()) {
      return _primary.get<T>();
    }

    final resolved = _binder.tryGet<T>();
    if (resolved != null) return resolved;

    // Preserve native GetIt error message for DX.
    return _primary.get<T>();
  }

  @override
  Future<T> getAsync<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) async {
    final usesAdvancedGetItFeatures =
        instanceName != null ||
        param1 != null ||
        param2 != null ||
        type != null;
    if (usesAdvancedGetItFeatures) {
      return _primary.getAsync<T>(
        instanceName: instanceName,
        param1: param1,
        param2: param2,
        type: type,
      );
    }

    if (_primary.isRegistered<T>()) {
      return _primary.getAsync<T>();
    }

    final resolved = _binder.tryGet<T>();
    if (resolved != null) return resolved;

    return _primary.getAsync<T>();
  }

  @override
  bool isRegistered<T extends Object>({
    Object? instance,
    String? instanceName,
    Type? type,
  }) {
    if (instanceName != null || instance != null || type != null) {
      return _primary.isRegistered<T>(
        instance: instance,
        instanceName: instanceName,
        type: type,
      );
    }
    if (_primary.isRegistered<T>()) return true;
    return _binder.contains(T);
  }

  @override
  void registerFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) => _primary.registerFactory<T>(factoryFunc, instanceName: instanceName);

  @override
  void registerFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) => _primary.registerFactoryParam<T, P1, P2>(
    factoryFunc,
    instanceName: instanceName,
  );

  @override
  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    DisposingFunc<T>? dispose,
    String? instanceName,
    void Function(T)? onCreated,
    bool useWeakReference = false,
  }) => _primary.registerLazySingleton<T>(
    factoryFunc,
    dispose: dispose,
    instanceName: instanceName,
    onCreated: onCreated,
    useWeakReference: useWeakReference,
  );

  @override
  T registerSingleton<T extends Object>(
    T instance, {
    DisposingFunc<T>? dispose,
    String? instanceName,
    bool? signalsReady,
  }) => _primary.registerSingleton<T>(
    instance,
    dispose: dispose,
    instanceName: instanceName,
    signalsReady: signalsReady ?? false,
  );

  @override
  void registerSingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    Iterable<Type>? dependsOn,
    DisposingFunc<T>? dispose,
    void Function(T)? onCreated,
    bool? signalsReady,
  }) => _primary.registerSingletonAsync<T>(
    factoryFunc,
    instanceName: instanceName,
    dependsOn: dependsOn,
    dispose: dispose,
    onCreated: onCreated,
    signalsReady: signalsReady ?? false,
  );

  @override
  void registerSingletonWithDependencies<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    required Iterable<Type>? dependsOn,
    DisposingFunc<T>? dispose,
    bool? signalsReady,
  }) => _primary.registerSingletonWithDependencies<T>(
    factoryFunc,
    instanceName: instanceName,
    dependsOn: dependsOn,
    dispose: dispose,
    signalsReady: signalsReady ?? false,
  );

  @override
  Future<void> allReady({
    Duration? timeout,
    bool ignorePendingAsyncCreation = false,
  }) => _primary.allReady(
    timeout: timeout,
    ignorePendingAsyncCreation: ignorePendingAsyncCreation,
  );

  @override
  bool allReadySync([bool ignorePendingAsyncCreation = false]) =>
      _primary.allReadySync(ignorePendingAsyncCreation);

  @override
  Future<void> reset({bool dispose = true}) => _primary.reset(dispose: dispose);

  @override
  FutureOr<void> resetLazySingleton<T extends Object>({
    DisposingFunc<T>? disposingFunction,
    T? instance,
    String? instanceName,
  }) => _primary.resetLazySingleton<T>(
    disposingFunction: disposingFunction,
    instance: instance,
    instanceName: instanceName,
  );

  @override
  FutureOr<void> unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    DisposingFunc<T>? disposingFunction,
    bool ignoreReferenceCount = false,
  }) => _primary.unregister<T>(
    instance: instance,
    instanceName: instanceName,
    disposingFunction: disposingFunction,
    ignoreReferenceCount: ignoreReferenceCount,
  );

  @override
  Future<void> isReady<T extends Object>({
    Object? instance,
    String? instanceName,
    Duration? timeout,
    Object? callee,
  }) => _primary.isReady<T>(
    instance: instance,
    instanceName: instanceName,
    timeout: timeout,
    callee: callee,
  );

  @override
  bool isReadySync<T extends Object>({
    Object? instance,
    String? instanceName,
  }) => _primary.isReadySync<T>(instance: instance, instanceName: instanceName);

  @override
  void signalReady(Object? instance) => _primary.signalReady(instance);

  @override
  String toString() => _primary.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'BinderGetIt does not support ${invocation.memberName}. '
      'Only the subset of GetIt API used by injectable is implemented.',
    );
  }
}
