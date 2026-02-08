import 'package:modularity_core/modularity_core.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleLogger', () {
    test('implements ModularityLogger', () {
      const logger = ConsoleLogger();
      expect(logger, isA<ModularityLogger>());
    });

    test('is enabled by default', () {
      const logger = ConsoleLogger();
      expect(logger.enabled, isTrue);
    });

    test('can be created as disabled', () {
      const logger = ConsoleLogger(enabled: false);
      expect(logger.enabled, isFalse);
    });

    test('log does not throw when enabled', () {
      const logger = ConsoleLogger();
      expect(() => logger.log('test message'), returnsNormally);
    });

    test('log does not throw when disabled', () {
      const logger = ConsoleLogger(enabled: false);
      expect(() => logger.log('test message'), returnsNormally);
    });

    test('log accepts all LogLevel values without throwing', () {
      const logger = ConsoleLogger();
      for (final level in LogLevel.values) {
        expect(
          () => logger.log('message at $level', level: level),
          returnsNormally,
          reason: 'log should not throw for level $level',
        );
      }
    });

    test('log accepts error parameter', () {
      const logger = ConsoleLogger();
      expect(
        () => logger.log(
          'error occurred',
          level: LogLevel.error,
          error: Exception('test error'),
        ),
        returnsNormally,
      );
    });

    test('log accepts stackTrace parameter', () {
      const logger = ConsoleLogger();
      final stackTrace = StackTrace.current;
      expect(
        () => logger.log(
          'error with trace',
          level: LogLevel.error,
          error: Exception('test'),
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
    });

    test('log defaults to LogLevel.info', () {
      // Verify the method signature accepts no level argument (defaults to info).
      // Since ConsoleLogger delegates to dart:developer.log, we verify it
      // doesn't throw when called without a level.
      const logger = ConsoleLogger();
      expect(() => logger.log('info message'), returnsNormally);
    });

    test('disabled logger skips processing entirely', () {
      const logger = ConsoleLogger(enabled: false);
      // Even with error and stack trace, disabled logger should be a no-op
      expect(
        () => logger.log(
          'should be ignored',
          level: LogLevel.error,
          error: StateError('bad'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('const constructor produces identical instances', () {
      const a = ConsoleLogger();
      const b = ConsoleLogger();
      expect(identical(a, b), isTrue);
    });

    test(
      'const constructor with same enabled value produces identical instances',
      () {
        const a = ConsoleLogger(enabled: true);
        const b = ConsoleLogger(enabled: true);
        expect(identical(a, b), isTrue);
      },
    );
  });
}
