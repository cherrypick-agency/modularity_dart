import 'package:modularity_cli/src/module_bindings_analyzer.dart';
import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:test/test.dart';

class _PrivateDependency {}

class ExposedService {}

class SampleModule extends Module {
  @override
  void binds(Binder i) {
    i.registerFactory<_PrivateDependency>(() => _PrivateDependency());
  }

  @override
  void exports(Binder i) {
    i.registerSingleton<ExposedService>(ExposedService());
  }
}

void main() {
  group('ModuleBindingsAnalyzer', () {
    test('collects private and public registrations', () {
      final analyzer = ModuleBindingsAnalyzer();
      final snapshot = analyzer.analyze(SampleModule());

      expect(snapshot.privateDependencies, hasLength(1));
      expect(
        snapshot.privateDependencies.first.displayName,
        '_PrivateDependency [factory]',
      );
      expect(snapshot.publicDependencies, hasLength(1));
      expect(
        snapshot.publicDependencies.first.displayName,
        'ExposedService [instance]',
      );
      expect(snapshot.warnings, isEmpty);
    });
  });
}
