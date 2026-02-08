import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

/// Service to track which override was applied.
abstract class ConfigService {
  String get variant;
}

class DefaultConfigService implements ConfigService {
  @override
  String get variant => 'default';
}

class VariantAConfigService implements ConfigService {
  @override
  String get variant => 'variant-a';
}

class VariantBConfigService implements ConfigService {
  @override
  String get variant => 'variant-b';
}

class ConfigModule extends Module {
  int initCount = 0;
  int disposeCount = 0;
  String? resolvedVariant;

  @override
  void binds(Binder binder) {
    binder.registerLazySingleton<ConfigService>(() => DefaultConfigService());
  }

  @override
  void exports(Binder binder) {
    binder.registerLazySingleton<ConfigService>(
      () => binder.get<ConfigService>(),
    );
  }

  @override
  Future<void> onInit() async {
    initCount++;
  }

  @override
  void onDispose() {
    disposeCount++;
  }
}

void main() {
  group('Override + Navigation E2E', () {
    late ModuleRetainer retainer;
    late GlobalKey<NavigatorState> navigatorKey;
    late List<String> lifecycleLog;

    setUp(() {
      retainer = ModuleRetainer();
      navigatorKey = GlobalKey<NavigatorState>();
      lifecycleLog = [];

      Modularity.lifecycleLogger = (event, type, {retentionKey, details}) {
        lifecycleLog.add('${event.name}:$type:$retentionKey');
      };
    });

    tearDown(() {
      Modularity.disableLogging();
    });

    testWidgets(
      'same module type with different overrides on separate routes',
      (tester) async {
        final module1 = ConfigModule();
        final module2 = ConfigModule();

        final overrideScopeA = ModuleOverrideScope(
          selfOverrides: (binder) {
            binder.registerLazySingleton<ConfigService>(
              () => VariantAConfigService(),
            );
          },
        );

        final overrideScopeB = ModuleOverrideScope(
          selfOverrides: (binder) {
            binder.registerLazySingleton<ConfigService>(
              () => VariantBConfigService(),
            );
          },
        );

        // Build initial route with module1 + overrideScopeA
        await tester.pumpWidget(
          ModularityRoot(
            retainer: retainer,
            child: MaterialApp(
              navigatorKey: navigatorKey,
              navigatorObservers: [Modularity.observer],
              home: ModuleScope(
                module: module1,
                retentionPolicy: ModuleRetentionPolicy.keepAlive,
                retentionKey: 'config-variant-a',
                overrideScope: overrideScopeA,
                child: Builder(
                  builder: (context) {
                    final service = ModuleProvider.of(
                      context,
                    ).get<ConfigService>();
                    return Text(
                      'Route1: ${service.variant}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify variant A is applied
        expect(find.text('Route1: variant-a'), findsOneWidget);
        expect(module1.initCount, 1);
        expect(retainer.debugSnapshot().length, 1);

        // Push new route with module2 + overrideScopeB
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => ModuleScope(
              module: module2,
              retentionPolicy: ModuleRetentionPolicy.keepAlive,
              retentionKey: 'config-variant-b',
              overrideScope: overrideScopeB,
              child: Builder(
                builder: (context) {
                  final service = ModuleProvider.of(
                    context,
                  ).get<ConfigService>();
                  return Text(
                    'Route2: ${service.variant}',
                    textDirection: TextDirection.ltr,
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify variant B is applied on route 2
        expect(find.text('Route2: variant-b'), findsOneWidget);
        expect(module2.initCount, 1);
        expect(retainer.debugSnapshot().length, 2);

        // Replace route 2 to trigger route termination
        navigatorKey.currentState!.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Text('Empty', textDirection: TextDirection.ltr),
          ),
        );
        await tester.pumpAndSettle();

        // Module2 should be evicted (route terminated)
        expect(module2.disposeCount, 1);
        expect(retainer.debugSnapshot().length, 1);

        // Module1 should still be alive (cached)
        expect(module1.disposeCount, 0);
      },
    );

    testWidgets(
      'same retentionKey with different overrides shares controller',
      (tester) async {
        final module1 = ConfigModule();
        final module2 = ConfigModule();

        final overrideA = ModuleOverrideScope(
          selfOverrides: (binder) {
            binder.registerLazySingleton<ConfigService>(
              () => VariantAConfigService(),
            );
          },
        );

        final overrideB = ModuleOverrideScope(
          selfOverrides: (binder) {
            binder.registerLazySingleton<ConfigService>(
              () => VariantBConfigService(),
            );
          },
        );

        // First route with override A
        await tester.pumpWidget(
          ModularityRoot(
            retainer: retainer,
            child: MaterialApp(
              navigatorKey: navigatorKey,
              navigatorObservers: [Modularity.observer],
              home: ModuleScope(
                module: module1,
                retentionPolicy: ModuleRetentionPolicy.keepAlive,
                retentionKey: 'shared-key', // Same key
                overrideScope: overrideA,
                child: Builder(
                  builder: (context) {
                    final service = ModuleProvider.of(
                      context,
                    ).get<ConfigService>();
                    return Text(
                      'Route1: ${service.variant}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Route1: variant-a'), findsOneWidget);
        expect(module1.initCount, 1);

        // Navigate away (module stays in cache)
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Text('Intermediate', textDirection: TextDirection.ltr),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to a new route with same key but different override
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => ModuleScope(
              module: module2,
              retentionPolicy: ModuleRetentionPolicy.keepAlive,
              retentionKey: 'shared-key', // Same key - should reuse!
              overrideScope: overrideB, // Different override - but key is same
              child: Builder(
                builder: (context) {
                  final service = ModuleProvider.of(
                    context,
                  ).get<ConfigService>();
                  return Text(
                    'Route3: ${service.variant}',
                    textDirection: TextDirection.ltr,
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should REUSE module1's controller (same key), NOT apply overrideB
        expect(find.text('Route3: variant-a'), findsOneWidget);
        expect(
          module2.initCount,
          0,
          reason: 'module2 should not be initialized',
        );
        expect(retainer.debugSnapshot().length, 1);
      },
    );

    testWidgets('lifecycle events are logged correctly', (tester) async {
      final module = ConfigModule();

      await tester.pumpWidget(
        ModularityRoot(
          retainer: retainer,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: [Modularity.observer],
            home: ModuleScope(
              module: module,
              retentionPolicy: ModuleRetentionPolicy.keepAlive,
              retentionKey: 'logged-module',
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have created and registered events
      expect(
        lifecycleLog,
        containsAll([
          contains('created:ConfigModule'),
          contains('registered:ConfigModule'),
        ]),
      );

      // Pop to trigger route termination
      navigatorKey.currentState!.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      );
      await tester.pumpAndSettle();

      // Should have route terminated and evicted events
      expect(
        lifecycleLog,
        containsAll([
          contains('routeTerminated:ConfigModule'),
          contains('evicted:ConfigModule'),
        ]),
      );
    });

    testWidgets('push-pop-push sequence with keepAlive', (tester) async {
      final module = ConfigModule();

      Widget buildHome() => ModuleScope(
        module: module,
        retentionPolicy: ModuleRetentionPolicy.keepAlive,
        retentionKey: 'home-module',
        child: const Text('Home', textDirection: TextDirection.ltr),
      );

      await tester.pumpWidget(
        ModularityRoot(
          retainer: retainer,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: [Modularity.observer],
            home: buildHome(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(module.initCount, 1);
      expect(module.disposeCount, 0);

      // Push detail screen
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Text('Detail', textDirection: TextDirection.ltr),
        ),
      );
      await tester.pumpAndSettle();

      // Home module should still be cached (not disposed)
      expect(module.disposeCount, 0);
      expect(retainer.debugSnapshot().length, 1);

      // Pop back to home
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      // Should reuse cached controller
      expect(module.initCount, 1, reason: 'Should reuse cached controller');
      expect(module.disposeCount, 0);
      expect(find.text('Home'), findsOneWidget);

      // Push and replace home route
      navigatorKey.currentState!.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Text('Replaced', textDirection: TextDirection.ltr),
        ),
      );
      await tester.pumpAndSettle();

      // Now home should be disposed (route terminated)
      expect(module.disposeCount, 1);
      expect(retainer.debugSnapshot(), isEmpty);
    });
  });
}
