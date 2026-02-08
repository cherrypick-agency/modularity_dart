import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:test/test.dart';

void main() {
  group('ModularityExportOnly filter', () {
    const filter = ModularityExportOnly();

    test(
      'canRegister returns true when depEnvironments contains export env',
      () {
        final envs = {modularityExportEnvName};

        expect(filter.canRegister(envs), isTrue);
      },
    );

    test('canRegister returns false when depEnvironments is empty', () {
      final envs = <String>{};

      expect(filter.canRegister(envs), isFalse);
    });

    test(
      'canRegister returns false when depEnvironments has other env only',
      () {
        final envs = {'dev', 'prod'};

        expect(filter.canRegister(envs), isFalse);
      },
    );

    test(
      'canRegister returns true when depEnvironments has multiple envs including export',
      () {
        final envs = {'dev', modularityExportEnvName, 'prod'};

        expect(filter.canRegister(envs), isTrue);
      },
    );

    test('modularityExportEnv has correct name', () {
      expect(modularityExportEnv.name, equals(modularityExportEnvName));
      expect(modularityExportEnvName, equals('modularity_export'));
    });
  });
}
