import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

class LifecycleModule extends Module {
  int initCount = 0;
  int disposeCount = 0;

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    initCount++;
  }

  @override
  void onDispose() {
    disposeCount++;
  }
}

class KeyedLifecycleModule extends LifecycleModule {
  KeyedLifecycleModule(this.id);

  final String id;

  @override
  Object get identityKey => id;
}

final _observer = RouteObserver<ModalRoute<dynamic>>();

Widget _buildHost({
  required bool showModule,
  required LifecycleModule module,
  required ModuleRetainer retainer,
  ModuleRetentionPolicy policy = ModuleRetentionPolicy.keepAlive,
}) {
  return ModularityRoot(
    observer: _observer,
    retainer: retainer,
    child: MaterialApp(
      navigatorObservers: [_observer],
      home: showModule
          ? ModuleScope(
              module: module,
              retentionPolicy: policy,
              child: const SizedBox.shrink(),
            )
          : const SizedBox.shrink(),
    ),
  );
}

void main() {
  group('KeepAlive retention', () {
    testWidgets('keeps module alive across widget remounts', (tester) async {
      final module = LifecycleModule();
      final retainer = ModuleRetainer();

      await tester.pumpWidget(
        _buildHost(showModule: true, module: module, retainer: retainer),
      );
      await tester.pumpAndSettle();

      expect(module.initCount, 1);
      expect(module.disposeCount, 0);
      expect(retainer.debugSnapshot().length, 1);

      await tester.pumpWidget(
        _buildHost(showModule: false, module: module, retainer: retainer),
      );
      await tester.pumpAndSettle();

      expect(
        module.disposeCount,
        0,
        reason: 'Controller should stay cached, not disposed',
      );

      await tester.pumpWidget(
        _buildHost(showModule: true, module: module, retainer: retainer),
      );
      await tester.pumpAndSettle();

      expect(
        module.initCount,
        1,
        reason: 'Cached controller should be reused without re-init',
      );
      expect(module.disposeCount, 0);
    });

    testWidgets('disposes cached controller when owning route pops', (
      tester,
    ) async {
      final module = LifecycleModule();
      final retainer = ModuleRetainer();
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ModularityRoot(
          observer: _observer,
          retainer: retainer,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: [_observer],
            home: ModuleScope(
              module: module,
              retentionPolicy: ModuleRetentionPolicy.keepAlive,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(module.initCount, 1);
      expect(retainer.debugSnapshot(), isNotEmpty);

      unawaited(
        navigatorKey.currentState!.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        module.disposeCount,
        1,
        reason: 'Route pop should dispose cached controller',
      );
      expect(retainer.debugSnapshot(), isEmpty);
    });

    testWidgets('evict removes cached controller', (tester) async {
      final module = LifecycleModule();
      final retainer = ModuleRetainer();

      await tester.pumpWidget(
        _buildHost(showModule: true, module: module, retainer: retainer),
      );
      await tester.pumpAndSettle();

      final snapshot = retainer.debugSnapshot();
      expect(snapshot, hasLength(1));

      await tester.runAsync(() async {
        await retainer.evict(snapshot.first.key);
      });

      expect(module.disposeCount, 1);
    });

    test('does not acquire stale disposed controller', () async {
      final module = LifecycleModule();
      final controller = ModuleController(module);
      final retainer = ModuleRetainer();

      await controller.initialize({});
      retainer.register(key: 'stale', controller: controller);
      await controller.dispose();

      expect(retainer.acquire('stale'), isNull);
      expect(retainer.debugSnapshot(), isEmpty);
    });

    testWidgets('evict without dispose detaches route listener', (
      tester,
    ) async {
      final module = LifecycleModule();
      final controller = ModuleController(module);
      final retainer = ModuleRetainer();
      final navigatorKey = GlobalKey<NavigatorState>();
      late ModalRoute<dynamic> route;
      var routeTerminations = 0;

      await controller.initialize({});

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) {
              route = ModalRoute.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      retainer.register(
        key: 'route-detach',
        controller: controller,
        route: route,
        onRouteTerminated: () {
          routeTerminations++;
        },
      );

      await retainer.evict('route-detach', disposeController: false);
      unawaited(
        navigatorKey.currentState!.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      expect(routeTerminations, 0);
      await controller.dispose();
    });

    test('rejects invalid retained controller entries', () async {
      final module = LifecycleModule();
      final controller = ModuleController(module);
      final retainer = ModuleRetainer();

      await controller.initialize({});
      await controller.dispose();

      expect(
        () => retainer.register(key: 'disposed', controller: controller),
        throwsA(isA<ModuleLifecycleException>()),
      );

      expect(
        () => retainer.register(
          key: 'negative-ref',
          controller: ModuleController(LifecycleModule()),
          initialRefCount: -1,
        ),
        throwsA(isA<ModuleLifecycleException>()),
      );
    });
  });

  group('KeepAlive with custom keys', () {
    testWidgets('modules with different retentionKeys are cached separately', (
      tester,
    ) async {
      final moduleA = LifecycleModule();
      final moduleB = LifecycleModule();
      final retainer = ModuleRetainer();

      await tester.pumpWidget(
        ModularityRoot(
          observer: _observer,
          retainer: retainer,
          child: MaterialApp(
            navigatorObservers: [_observer],
            home: Column(
              children: [
                ModuleScope(
                  module: moduleA,
                  retentionPolicy: ModuleRetentionPolicy.keepAlive,
                  retentionKey: 'key-a',
                  child: const SizedBox.shrink(),
                ),
                ModuleScope(
                  module: moduleB,
                  retentionPolicy: ModuleRetentionPolicy.keepAlive,
                  retentionKey: 'key-b',
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(moduleA.initCount, 1);
      expect(moduleB.initCount, 1);
      expect(retainer.debugSnapshot().length, 2);
    });

    testWidgets('module identityKey separates default keepAlive keys', (
      tester,
    ) async {
      final moduleA = KeyedLifecycleModule('tenant-a');
      final moduleB = KeyedLifecycleModule('tenant-b');
      final retainer = ModuleRetainer();

      await tester.pumpWidget(
        ModularityRoot(
          observer: _observer,
          retainer: retainer,
          child: MaterialApp(
            navigatorObservers: [_observer],
            home: Column(
              children: [
                ModuleScope(
                  module: moduleA,
                  retentionPolicy: ModuleRetentionPolicy.keepAlive,
                  child: const SizedBox.shrink(),
                ),
                ModuleScope(
                  module: moduleB,
                  retentionPolicy: ModuleRetentionPolicy.keepAlive,
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(moduleA.initCount, 1);
      expect(moduleB.initCount, 1);
      expect(retainer.debugSnapshot(), hasLength(2));
    });

    testWidgets('evicting one retention key variant does not affect another', (
      tester,
    ) async {
      final module1 = LifecycleModule();
      final module2 = LifecycleModule();
      final retainer = ModuleRetainer();

      await tester.pumpWidget(
        ModularityRoot(
          observer: _observer,
          retainer: retainer,
          child: MaterialApp(
            navigatorObservers: [_observer],
            home: Column(
              children: [
                ModuleScope(
                  module: module1,
                  retentionPolicy: ModuleRetentionPolicy.keepAlive,
                  retentionKey: 'module-1',
                  child: const SizedBox.shrink(),
                ),
                ModuleScope(
                  module: module2,
                  retentionPolicy: ModuleRetentionPolicy.keepAlive,
                  retentionKey: 'module-2',
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final snapshot = retainer.debugSnapshot();
      expect(snapshot.length, 2);

      await tester.runAsync(() async {
        await retainer.evict(snapshot.first.key);
      });

      expect(module1.disposeCount, 1);
      expect(module2.disposeCount, 0);
      expect(retainer.debugSnapshot().length, 1);
    });
  });

  group('Strict retention', () {
    testWidgets('disposes controller on widget unmount', (tester) async {
      final module = LifecycleModule();
      final retainer = ModuleRetainer();

      await tester.pumpWidget(
        _buildHost(
          showModule: true,
          module: module,
          retainer: retainer,
          policy: ModuleRetentionPolicy.strict,
        ),
      );
      await tester.pumpAndSettle();

      expect(module.initCount, 1);

      await tester.pumpWidget(
        _buildHost(
          showModule: false,
          module: module,
          retainer: retainer,
          policy: ModuleRetentionPolicy.strict,
        ),
      );
      await tester.pumpAndSettle();

      expect(module.disposeCount, 1);
      expect(retainer.debugSnapshot(), isEmpty);
    });
  });
}
