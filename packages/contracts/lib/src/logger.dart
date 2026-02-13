/// Severity levels for framework log messages.
///
/// Ordered from least to most severe: [debug] < [info] < [warning] < [error].
enum LogLevel {
  /// Verbose diagnostics useful during development.
  debug,

  /// Informational messages about normal operation.
  info,

  /// Conditions that may indicate a problem.
  warning,

  /// Errors that require attention.
  error,
}

/// Contract for logging framework events.
///
/// Implement this interface to route Modularity log output to your
/// preferred logging backend (e.g. `package:logging`, Crashlytics).
///
/// ```dart
/// class PrintLogger implements ModularityLogger {
///   @override
///   void log(
///     String message, {
///     LogLevel level = LogLevel.info,
///     Object? error,
///     StackTrace? stackTrace,
///   }) {
///     print('[$level] $message');
///   }
/// }
/// ```
///
/// See also:
/// - `ConsoleLogger` in `modularity_core` for a default implementation
///   that uses `dart:developer`.
abstract class ModularityLogger {
  /// Emits a log entry with the given [message] and optional metadata.
  ///
  /// [level] defaults to [LogLevel.info]. Pass [error] and [stackTrace]
  /// to attach exception details.
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  });
}
