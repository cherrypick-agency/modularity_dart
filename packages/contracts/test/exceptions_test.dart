import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('ModularityException', () {
    test('stores the message', () {
      const exception = ModularityException('something went wrong');
      expect(exception.message, equals('something went wrong'));
    });

    test('toString() includes the class prefix and message', () {
      const exception = ModularityException('oops');
      expect(exception.toString(), equals('ModularityException: oops'));
    });

    test('implements Exception', () {
      const exception = ModularityException('test');
      expect(exception, isA<Exception>());
    });

    test('can be caught as Exception', () {
      expect(
        () => throw const ModularityException('catch me'),
        throwsA(isA<Exception>()),
      );
    });

    test('can be caught as ModularityException', () {
      expect(
        () => throw const ModularityException('catch me'),
        throwsA(isA<ModularityException>()),
      );
    });

    test('handles empty message', () {
      const exception = ModularityException('');
      expect(exception.message, equals(''));
      expect(exception.toString(), equals('ModularityException: '));
    });

    test('handles message with special characters', () {
      const exception = ModularityException('Error: "foo" -> bar\nnewline');
      expect(exception.message, contains('"foo"'));
      expect(exception.message, contains('\n'));
    });
  });

  group('DependencyNotFoundException', () {
    test('stores all required and optional parameters', () {
      const exception = DependencyNotFoundException(
        'not found',
        requestedType: String,
        availableTypes: [int, double],
        lookupContext: 'parent scope',
      );

      expect(exception.message, equals('not found'));
      expect(exception.requestedType, equals(String));
      expect(exception.availableTypes, equals([int, double]));
      expect(exception.lookupContext, equals('parent scope'));
    });

    test('extends ModularityException', () {
      const exception = DependencyNotFoundException(
        'missing',
        requestedType: String,
      );
      expect(exception, isA<ModularityException>());
    });

    test('implements Exception through hierarchy', () {
      const exception = DependencyNotFoundException(
        'missing',
        requestedType: String,
      );
      expect(exception, isA<Exception>());
    });

    test('can be caught as ModularityException', () {
      expect(
        () => throw const DependencyNotFoundException(
          'missing',
          requestedType: int,
        ),
        throwsA(isA<ModularityException>()),
      );
    });

    test('availableTypes defaults to empty list', () {
      const exception = DependencyNotFoundException(
        'missing',
        requestedType: String,
      );
      expect(exception.availableTypes, isEmpty);
    });

    test('lookupContext defaults to null', () {
      const exception = DependencyNotFoundException(
        'missing',
        requestedType: String,
      );
      expect(exception.lookupContext, isNull);
    });

    test('toString() includes available types when non-empty', () {
      const exception = DependencyNotFoundException(
        'not found',
        requestedType: String,
        availableTypes: [int, double],
      );
      final str = exception.toString();
      expect(str, contains('DependencyNotFoundException: not found'));
      expect(str, contains('Available types: [int, double]'));
    });

    test('toString() omits available types when empty', () {
      const exception = DependencyNotFoundException(
        'not found',
        requestedType: String,
      );
      final str = exception.toString();
      expect(str, equals('DependencyNotFoundException: not found'));
      expect(str, isNot(contains('Available types')));
    });

    test('toString() includes lookup context when provided', () {
      const exception = DependencyNotFoundException(
        'not found',
        requestedType: String,
        lookupContext: 'GetItBinder scope',
      );
      final str = exception.toString();
      expect(str, contains('Lookup context: GetItBinder scope'));
    });

    test('toString() omits lookup context when null', () {
      const exception = DependencyNotFoundException(
        'not found',
        requestedType: String,
      );
      final str = exception.toString();
      expect(str, isNot(contains('Lookup context')));
    });

    test('toString() includes both available types and lookup context', () {
      const exception = DependencyNotFoundException(
        'not found',
        requestedType: String,
        availableTypes: [int],
        lookupContext: 'test scope',
      );
      final str = exception.toString();
      expect(str, contains('DependencyNotFoundException: not found'));
      expect(str, contains('Available types: [int]'));
      expect(str, contains('Lookup context: test scope'));
    });
  });

  group('CircularDependencyException', () {
    test('stores message and dependency chain', () {
      const exception = CircularDependencyException(
        'cycle detected',
        dependencyChain: [String, int, String],
      );

      expect(exception.message, equals('cycle detected'));
      expect(exception.dependencyChain, equals([String, int, String]));
    });

    test('extends ModularityException', () {
      const exception = CircularDependencyException('cycle');
      expect(exception, isA<ModularityException>());
    });

    test('implements Exception through hierarchy', () {
      const exception = CircularDependencyException('cycle');
      expect(exception, isA<Exception>());
    });

    test('dependencyChain defaults to empty list', () {
      const exception = CircularDependencyException('cycle');
      expect(exception.dependencyChain, isEmpty);
    });

    test('toString() includes dependency chain when non-empty', () {
      const exception = CircularDependencyException(
        'cycle found',
        dependencyChain: [String, int, double],
      );
      final str = exception.toString();
      expect(str, contains('CircularDependencyException: cycle found'));
      expect(str, contains('Dependency chain: String -> int -> double'));
    });

    test('toString() omits dependency chain when empty', () {
      const exception = CircularDependencyException('cycle found');
      final str = exception.toString();
      expect(str, equals('CircularDependencyException: cycle found'));
      expect(str, isNot(contains('Dependency chain')));
    });

    test('can be caught as ModularityException', () {
      expect(
        () => throw const CircularDependencyException('cycle'),
        throwsA(isA<ModularityException>()),
      );
    });

    test('single-element chain renders correctly', () {
      const exception = CircularDependencyException(
        'self-ref',
        dependencyChain: [String],
      );
      expect(exception.toString(), contains('Dependency chain: String'));
    });
  });

  group('ModuleConfigurationException', () {
    test('stores message and optional moduleType', () {
      const exception = ModuleConfigurationException(
        'bad config',
        moduleType: String,
      );

      expect(exception.message, equals('bad config'));
      expect(exception.moduleType, equals(String));
    });

    test('extends ModularityException', () {
      const exception = ModuleConfigurationException('bad');
      expect(exception, isA<ModularityException>());
    });

    test('implements Exception through hierarchy', () {
      const exception = ModuleConfigurationException('bad');
      expect(exception, isA<Exception>());
    });

    test('moduleType defaults to null', () {
      const exception = ModuleConfigurationException('bad');
      expect(exception.moduleType, isNull);
    });

    test('toString() includes module type when provided', () {
      const exception = ModuleConfigurationException(
        'bad config',
        moduleType: int,
      );
      final str = exception.toString();
      expect(str, contains('ModuleConfigurationException: bad config'));
      expect(str, contains('Module type: int'));
    });

    test('toString() omits module type when null', () {
      const exception = ModuleConfigurationException('bad config');
      final str = exception.toString();
      expect(str, equals('ModuleConfigurationException: bad config'));
      expect(str, isNot(contains('Module type')));
    });

    test('can be caught as ModularityException', () {
      expect(
        () => throw const ModuleConfigurationException('bad'),
        throwsA(isA<ModularityException>()),
      );
    });
  });

  group('ModuleLifecycleException', () {
    test('stores all parameters', () {
      const exception = ModuleLifecycleException(
        'lifecycle error',
        moduleType: String,
        state: ModuleStatus.loading,
      );

      expect(exception.message, equals('lifecycle error'));
      expect(exception.moduleType, equals(String));
      expect(exception.state, equals(ModuleStatus.loading));
    });

    test('extends ModularityException', () {
      const exception = ModuleLifecycleException('err');
      expect(exception, isA<ModularityException>());
    });

    test('implements Exception through hierarchy', () {
      const exception = ModuleLifecycleException('err');
      expect(exception, isA<Exception>());
    });

    test('moduleType and state default to null', () {
      const exception = ModuleLifecycleException('err');
      expect(exception.moduleType, isNull);
      expect(exception.state, isNull);
    });

    test('toString() includes module type and state when provided', () {
      const exception = ModuleLifecycleException(
        'failed',
        moduleType: int,
        state: ModuleStatus.error,
      );
      final str = exception.toString();
      expect(str, contains('ModuleLifecycleException: failed'));
      expect(str, contains('Module type: int'));
      expect(str, contains('State: ModuleStatus.error'));
    });

    test('toString() includes only module type when state is null', () {
      const exception = ModuleLifecycleException('failed', moduleType: int);
      final str = exception.toString();
      expect(str, contains('Module type: int'));
      expect(str, isNot(contains('State:')));
    });

    test('toString() includes only state when module type is null', () {
      const exception = ModuleLifecycleException(
        'failed',
        state: ModuleStatus.loading,
      );
      final str = exception.toString();
      expect(str, isNot(contains('Module type:')));
      expect(str, contains('State: ModuleStatus.loading'));
    });

    test('toString() omits both when both are null', () {
      const exception = ModuleLifecycleException('failed');
      final str = exception.toString();
      expect(str, equals('ModuleLifecycleException: failed'));
    });

    test('can be caught as ModularityException', () {
      expect(
        () => throw const ModuleLifecycleException('err'),
        throwsA(isA<ModularityException>()),
      );
    });

    test('works with all ModuleStatus values', () {
      for (final status in ModuleStatus.values) {
        final exception = ModuleLifecycleException('test', state: status);
        expect(exception.state, equals(status));
        expect(exception.toString(), contains('State: ${status.toString()}'));
      }
    });
  });

  group('Exception hierarchy', () {
    test('all exception types extend ModularityException', () {
      expect(
        const DependencyNotFoundException('x', requestedType: String),
        isA<ModularityException>(),
      );
      expect(
        const CircularDependencyException('x'),
        isA<ModularityException>(),
      );
      expect(
        const ModuleConfigurationException('x'),
        isA<ModularityException>(),
      );
      expect(const ModuleLifecycleException('x'), isA<ModularityException>());
    });

    test('all exception types implement Exception', () {
      expect(
        const DependencyNotFoundException('x', requestedType: String),
        isA<Exception>(),
      );
      expect(const CircularDependencyException('x'), isA<Exception>());
      expect(const ModuleConfigurationException('x'), isA<Exception>());
      expect(const ModuleLifecycleException('x'), isA<Exception>());
    });

    test('catching ModularityException catches all subtypes', () {
      final exceptions = <Exception>[
        const DependencyNotFoundException('a', requestedType: String),
        const CircularDependencyException('b'),
        const ModuleConfigurationException('c'),
        const ModuleLifecycleException('d'),
      ];

      for (final exception in exceptions) {
        var caught = false;
        try {
          throw exception;
          // ignore: avoid_catching_errors
        } on ModularityException {
          caught = true;
        }
        expect(caught, isTrue, reason: '${exception.runtimeType} not caught');
      }
    });
  });
}
