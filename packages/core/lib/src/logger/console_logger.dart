import 'dart:developer' as developer;
import 'package:modularity_contracts/modularity_contracts.dart';

/// Default [ModularityLogger] that forwards messages to `dart:developer`
/// via [developer.log].
///
/// All entries are emitted under the `modularity` log name. Disable
/// output by setting [enabled] to `false`.
///
/// ```dart
/// final logger = ConsoleLogger(enabled: true);
/// logger.log('Module loaded', level: LogLevel.info);
/// ```
///
/// See also:
/// - [ModularityLogger] for the logging contract.
class ConsoleLogger implements ModularityLogger {
  /// Creates a [ConsoleLogger] that is [enabled] by default.
  const ConsoleLogger({this.enabled = true});

  /// Whether logging output is active. Set to `false` to suppress all messages.
  final bool enabled;

  /// Writes a log [message] at the given [level] via `dart:developer`.
  @override
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;

    developer.log(
      message,
      name: 'modularity',
      level: _mapLevel(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  int _mapLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
