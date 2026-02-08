import 'dart:async';
import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_core/src/graph/graph_resolver.dart';
import 'package:test/test.dart';

// -- Test module helpers --

/// A simple leaf module with no imports.
class LeafModule extends Module {
  LeafModule(this.log);
  final List<String> log;

  @override
  void binds(Binder i) {
    i.registerSingleton<String>('from_leaf');
  }

  @override
  void exports(Binder i) {
    i.registerSingleton<String>('from_leaf');
  }

  @override
  Future<void> onInit() async {
    log.add('LeafModule.onInit');
  }
}

/// Module that imports a single LeafModule.
class SingleImportModule extends Module {
  SingleImportModule(this.log);
  final List<String> log;

  late final LeafModule _leaf = LeafModule(log);

  @override
  List<Module> get imports => [_leaf];

  @override
  void binds(Binder i) {
    log.add('SingleImportModule.binds');
  }
}

/// Shared module used as a diamond dependency base.
class SharedModule extends Module {
  static int initCount = 0;

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    initCount++;
  }
}

/// Left branch of the diamond.
class LeftModule extends Module {
  @override
  List<Module> get imports => [SharedModule()];

  @override
  void binds(Binder i) {}
}

/// Right branch of the diamond.
class RightModule extends Module {
  @override
  List<Module> get imports => [SharedModule()];

  @override
  void binds(Binder i) {}
}

/// Root of diamond dependency: imports both LeftModule and RightModule,
/// each of which imports SharedModule.
class DiamondRootModule extends Module {
  @override
  List<Module> get imports => [LeftModule(), RightModule()];

  @override
  void binds(Binder i) {}
}

/// Module whose onInit throws an error.
class FailingModule extends Module {
  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    throw Exception('FailingModule error');
  }
}

/// Module that imports a FailingModule.
class DependsOnFailingModule extends Module {
  @override
  List<Module> get imports => [FailingModule()];

  @override
  void binds(Binder i) {}
}

/// Module with circular dependency A -> B -> A.
class CircularModuleA extends Module {
  @override
  List<Module> get imports => [CircularModuleB()];

  @override
  void binds(Binder i) {}
}

class CircularModuleB extends Module {
  @override
  List<Module> get imports => [CircularModuleA()];

  @override
  void binds(Binder i) {}
}

/// Module with three-way circular dependency: A -> B -> C -> A.
class CycleA extends Module {
  @override
  List<Module> get imports => [CycleB()];

  @override
  void binds(Binder i) {}
}

class CycleB extends Module {
  @override
  List<Module> get imports => [CycleC()];

  @override
  void binds(Binder i) {}
}

class CycleC extends Module {
  @override
  List<Module> get imports => [CycleA()];

  @override
  void binds(Binder i) {}
}

/// Module whose onInit takes a long time, used to test concurrent waiting.
class SlowModule extends Module {
  SlowModule(this.completer);
  final Completer<void> completer;

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    await completer.future;
  }
}

/// Module whose onInit fails after a delay, used to verify that a waiting
/// branch does not hang indefinitely when the primary initializer errors.
class SlowFailingModule extends Module {
  final Completer<void> _startedCompleter = Completer<void>();

  Future<void> get started => _startedCompleter.future;

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    _startedCompleter.complete();
    // Simulate async work then fail
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw Exception('slow module failed');
  }
}

/// Two modules that both import the same SlowFailingModule, enabling tests
/// where two concurrent branches await the same dependency.
class BranchA extends Module {
  BranchA(this.shared);
  final Module shared;

  @override
  List<Module> get imports => [shared];

  @override
  void binds(Binder i) {}
}

class BranchB extends Module {
  BranchB(this.shared);
  final Module shared;

  @override
  List<Module> get imports => [shared];

  @override
  void binds(Binder i) {}
}

/// Root module that imports BranchA and BranchB (diamond with slow failing
/// shared dependency).
class ConcurrentRoot extends Module {
  ConcurrentRoot(this.branchA, this.branchB);
  final Module branchA;
  final Module branchB;

  @override
  List<Module> get imports => [branchA, branchB];

  @override
  void binds(Binder i) {}
}

void main() {
  group('GraphResolver', () {
    late GraphResolver resolver;
    late Map<ModuleRegistryKey, ModuleController> registry;
    late BinderFactory binderFactory;

    setUp(() {
      resolver = GraphResolver();
      registry = {};
      binderFactory = SimpleBinderFactory();
    });

    group('resolveAndInitImports', () {
      test('resolves a simple single import', () async {
        final log = <String>[];
        final root = SingleImportModule(log);

        final controllers = await resolver.resolveAndInitImports(
          root,
          registry,
          binderFactory,
        );

        expect(controllers, hasLength(1));
        expect(controllers.first.currentStatus, equals(ModuleStatus.loaded));
        expect(log, contains('LeafModule.onInit'));
      });

      test('diamond dependency initializes shared module only once', () async {
        SharedModule.initCount = 0;
        final root = DiamondRootModule();

        final controller = ModuleController(root);
        await controller.initialize(registry);

        // SharedModule should only be initialized once despite being imported
        // by both LeftModule and RightModule
        expect(SharedModule.initCount, equals(1));
      });

      test('returns controllers in the same order as imports', () async {
        final log = <String>[];
        final root = SingleImportModule(log);

        final controllers = await resolver.resolveAndInitImports(
          root,
          registry,
          binderFactory,
        );

        expect(controllers.first.module, isA<LeafModule>());
      });
    });

    group('error propagation', () {
      test('propagates error when imported module onInit fails', () async {
        final root = DependsOnFailingModule();
        final controller = ModuleController(root);

        await expectLater(
          () => controller.initialize(registry),
          throwsA(isA<Exception>()),
        );
      });

      test('sets error status when imported module fails', () async {
        final root = DependsOnFailingModule();
        final controller = ModuleController(root);

        try {
          await controller.initialize(registry);
        } catch (_) {}

        expect(controller.currentStatus, equals(ModuleStatus.error));
      });
    });

    group('concurrent branch error handling', () {
      test(
        'waiting branch throws when shared dependency errors instead of hanging',
        () async {
          // This tests the fix for issue 1.1: when a concurrent branch's
          // module fails, the waiting branch should throw ModuleLifecycleException
          // rather than hanging forever.
          final slowFailing = SlowFailingModule();
          final branchA = BranchA(slowFailing);
          final branchB = BranchB(slowFailing);
          final root = ConcurrentRoot(branchA, branchB);

          final controller = ModuleController(root);

          await expectLater(
            () => controller.initialize(registry),
            throwsA(isA<Exception>()),
          );

          // Verify the controller is in error state, not stuck in loading
          expect(controller.currentStatus, equals(ModuleStatus.error));
        },
        timeout: const Timeout(Duration(seconds: 5)),
      );
    });

    group('circular dependency detection', () {
      test('detects A -> B -> A circular dependency', () async {
        final controller = ModuleController(CircularModuleA());

        await expectLater(
          () => controller.initialize(registry),
          throwsA(isA<CircularDependencyException>()),
        );
      });

      test('detects three-way cycle A -> B -> C -> A', () async {
        final controller = ModuleController(CycleA());

        await expectLater(
          () => controller.initialize(registry),
          throwsA(isA<CircularDependencyException>()),
        );
      });

      test('circular dependency exception contains the chain', () async {
        final controller = ModuleController(CircularModuleA());

        try {
          await controller.initialize(registry);
          fail('Should have thrown');
        } on CircularDependencyException catch (e) {
          expect(e.dependencyChain, isNotEmpty);
          expect(e.message, contains('Circular dependency detected'));
        }
      });
    });

    group('registry reuse', () {
      test('reuses already-loaded controller from registry', () async {
        // Pre-populate the registry with a loaded controller for LeafModule
        final leafModule = LeafModule([]);
        final leafController = ModuleController(leafModule);
        final preLoadedKey = ModuleRegistryKey(moduleType: LeafModule);
        registry[preLoadedKey] = leafController;
        await leafController.initialize(registry);

        expect(registry[preLoadedKey]!.currentStatus, ModuleStatus.loaded);

        // Now resolve again with a module that imports the same type
        final log = <String>[];
        final root = SingleImportModule(log);
        final controllers = await resolver.resolveAndInitImports(
          root,
          registry,
          binderFactory,
        );

        // The registry should still contain exactly one controller for
        // LeafModule (same type, no override scope).
        final leafKeys = registry.keys
            .where((k) => k.moduleType == LeafModule)
            .toList();
        expect(leafKeys, hasLength(1));
        expect(controllers, hasLength(1));
        // The returned controller should be the same pre-loaded one
        expect(controllers.first, same(leafController));
      });
    });
  });
}
