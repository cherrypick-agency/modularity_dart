import 'package:test/test.dart';
import 'package:modularity_core/modularity_core.dart';

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

void main() {
  group('Circular Dependency Detection', () {
    test('detects direct circular dependency (A -> B -> A)', () async {
      final controller = ModuleController(ModuleA());

      expect(
        () => controller.initialize({}),
        throwsA(predicate(
            (e) => e.toString().contains('Circular dependency detected'))),
      );
    });

    test('detects self-dependency (A -> A)', () async {
      final controller = ModuleController(ModuleSelf());

      expect(
        () => controller.initialize({}),
        throwsA(predicate(
            (e) => e.toString().contains('Circular dependency detected'))),
      );
    });
  });
}
