import 'package:modularity_core/modularity_core.dart';
import 'package:test/test.dart';

class ModuleA extends Module {
  @override
  List<Module> get imports => [ModuleB()];

  @override
  void binds(Binder i) {}
}

class ModuleB extends Module {
  @override
  List<Module> get imports => [ModuleA()]; // Circular!

  @override
  void binds(Binder i) {}
}

class ModuleSelf extends Module {
  @override
  List<Module> get imports => [ModuleSelf()]; // Self-Circular!

  @override
  void binds(Binder i) {}
}

class ChainedKeyedModule extends Module {
  ChainedKeyedModule(this.id, {this.childId});

  static int initCount = 0;

  final String id;
  final String? childId;

  @override
  Object get identityKey => id;

  @override
  List<Module> get imports => [
    if (childId != null) ChainedKeyedModule(childId!),
  ];

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    initCount++;
  }
}

void main() {
  group('Circular Dependency Detection', () {
    setUp(() {
      ChainedKeyedModule.initCount = 0;
    });

    test('detects direct circular dependency (A -> B -> A)', () async {
      final controller = ModuleController(ModuleA());

      expect(
        () => controller.initialize(<ModuleRegistryKey, ModuleController>{}),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('detects self-dependency (A -> A)', () async {
      final controller = ModuleController(ModuleSelf());

      expect(
        () => controller.initialize(<ModuleRegistryKey, ModuleController>{}),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('allows same module type chain with different identityKey', () async {
      final controller = ModuleController(
        ChainedKeyedModule('parent', childId: 'child'),
      );
      final registry = <ModuleRegistryKey, ModuleController>{};

      await controller.initialize(registry);

      expect(ChainedKeyedModule.initCount, 2);
      expect(
        registry.keys.where((key) => key.moduleType == ChainedKeyedModule),
        hasLength(1),
      );
    });

    test('detects same module type cycle with same identityKey', () async {
      final controller = ModuleController(
        ChainedKeyedModule('same', childId: 'same'),
      );

      await expectLater(
        () => controller.initialize(<ModuleRegistryKey, ModuleController>{}),
        throwsA(isA<CircularDependencyException>()),
      );
    });
  });
}
