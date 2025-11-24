import 'dart:developer' as developer;
import 'package:modularity_contracts/modularity_contracts.dart';

class ConsoleLogger implements ModularityLogger {
  final bool enabled;

  const ConsoleLogger({this.enabled = true});

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
