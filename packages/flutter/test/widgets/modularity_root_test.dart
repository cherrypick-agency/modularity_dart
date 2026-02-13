import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _StubInterceptor implements ModuleInterceptor {
  @override
  void onInit(Module module) {}
  @override
  void onLoaded(Module module) {}
  @override
  void onError(Module module, Object error) {}
  @override
  void onDispose(Module module) {}
}

class _DummyModule extends Module {
  @override
  void binds(Binder i) {}
}

/// Wraps [ModularityRoot] with a [MaterialApp] so `pumpWidget` works.
Widget _wrap({
  BinderFactory? binderFactory,
  RouteObserver<ModalRoute<dynamic>>? observer,
  ModuleRetainer? retainer,
  List<ModuleInterceptor>? interceptors,
  ModuleLifecycleLogger? lifecycleLogger,
}) {
  return ModularityRoot(
    binderFactory: binderFactory,
    observer: observer,
    retainer: retainer,
    interceptors: interceptors,
    lifecycleLogger: lifecycleLogger,
    child: const MaterialApp(home: SizedBox()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('didUpdateWidget — immutable field protection', () {
    testWidgets('reports error when binderFactory changes', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      addTearDown(() => FlutterError.onError = oldHandler);

      final factory1 = SimpleBinderFactory();
      final factory2 = SimpleBinderFactory();

      await tester.pumpWidget(_wrap(binderFactory: factory1));
      await tester.pumpWidget(_wrap(binderFactory: factory2));

      expect(errors, hasLength(1));
      expect(
        errors.first.exception.toString(),
        contains('binderFactory must not change'),
      );
    });

    testWidgets('reports error when observer changes', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      addTearDown(() => FlutterError.onError = oldHandler);

      final observer1 = RouteObserver<ModalRoute<dynamic>>();
      final observer2 = RouteObserver<ModalRoute<dynamic>>();

      await tester.pumpWidget(_wrap(observer: observer1));
      await tester.pumpWidget(_wrap(observer: observer2));

      expect(errors, hasLength(1));
      expect(
        errors.first.exception.toString(),
        contains('observer must not change'),
      );
    });

    testWidgets('reports error when retainer changes', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      addTearDown(() => FlutterError.onError = oldHandler);

      final retainer1 = ModuleRetainer();
      final retainer2 = ModuleRetainer();

      await tester.pumpWidget(_wrap(retainer: retainer1));
      await tester.pumpWidget(_wrap(retainer: retainer2));

      expect(errors, hasLength(1));
      expect(
        errors.first.exception.toString(),
        contains('retainer must not change'),
      );
    });

    testWidgets('reports error when interceptors changes', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      addTearDown(() => FlutterError.onError = oldHandler);

      final interceptor1 = _StubInterceptor();
      final interceptor2 = _StubInterceptor();

      await tester.pumpWidget(_wrap(interceptors: [interceptor1]));
      await tester.pumpWidget(_wrap(interceptors: [interceptor2]));

      expect(errors, hasLength(1));
      expect(
        errors.first.exception.toString(),
        contains('interceptors must not change'),
      );
    });
  });

  group('didUpdateWidget — lifecycleLogger hot-swap', () {
    testWidgets('allows lifecycleLogger change without error', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      addTearDown(() => FlutterError.onError = oldHandler);

      void logger1(
        ModuleLifecycleEvent event,
        Type moduleType, {
        Object? retentionKey,
        Map<String, Object?>? details,
      }) {}

      void logger2(
        ModuleLifecycleEvent event,
        Type moduleType, {
        Object? retentionKey,
        Map<String, Object?>? details,
      }) {}

      final observer = RouteObserver<ModalRoute<dynamic>>();
      final retainer = ModuleRetainer();

      await tester.pumpWidget(
        _wrap(observer: observer, retainer: retainer, lifecycleLogger: logger1),
      );
      await tester.pumpWidget(
        _wrap(observer: observer, retainer: retainer, lifecycleLogger: logger2),
      );

      expect(errors, isEmpty);
      expect(retainer.logger, same(logger2));
    });
  });

  group('dispose', () {
    testWidgets('clears registry and nulls retainer logger on dispose', (
      tester,
    ) async {
      final retainer = ModuleRetainer();
      final observer = RouteObserver<ModalRoute<dynamic>>();

      void logger(
        ModuleLifecycleEvent event,
        Type moduleType, {
        Object? retentionKey,
        Map<String, Object?>? details,
      }) {}

      await tester.pumpWidget(
        ModularityRoot(
          observer: observer,
          retainer: retainer,
          lifecycleLogger: logger,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final registry = ModularityRoot.registryOf(context);
                final controller = ModuleController(
                  _DummyModule(),
                  binderFactory: SimpleBinderFactory(),
                );
                registry[ModuleRegistryKey(moduleType: _DummyModule)] =
                    controller;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(retainer.logger, same(logger));

      // Replace the widget tree — triggers dispose of ModularityRoot.
      await tester.pumpWidget(const SizedBox());

      expect(retainer.logger, isNull);
    });
  });

  group('initState defaults', () {
    testWidgets('creates default observer when not provided', (tester) async {
      late RouteObserver<ModalRoute<dynamic>> resolvedObserver;

      await tester.pumpWidget(
        ModularityRoot(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                resolvedObserver = ModularityRoot.observerOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedObserver, isNotNull);
      expect(resolvedObserver, isA<RouteObserver<ModalRoute<dynamic>>>());
    });
  });
}
