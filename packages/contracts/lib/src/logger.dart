/// Уровни логирования
enum LogLevel { debug, info, warning, error }

/// Интерфейс для логирования событий фреймворка.
abstract class ModularityLogger {
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  });
}
