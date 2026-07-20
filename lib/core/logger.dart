import 'dart:developer' as developer;

enum LogLevel { debug, info, warn, error }

/// Release-mode flag, read without importing Flutter.
///
/// `kReleaseMode` lives in `package:flutter/foundation.dart`, and depending on
/// it here would make the logger — and therefore anything that logs, including
/// the pure-Dart simulation — unusable outside a Flutter test harness. The VM
/// sets `dart.vm.product` in release builds, which is the same signal without
/// the dependency. See docs/12-architecture.md §12.0.
const bool kIsReleaseBuild = bool.fromEnvironment('dart.vm.product');

/// Minimal structured logger.
///
/// Deliberately not a package: this needs to be callable from the pure-Dart
/// simulation, which cannot depend on Flutter, and it needs to be a no-op in
/// release so that logging never costs frame time. Anything richer belongs in
/// the analytics port instead.
abstract interface class Logger {
  void log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  });
}

extension LoggerShorthand on Logger {
  void d(String message, {String? tag, Map<String, Object?>? data}) =>
      log(LogLevel.debug, message, tag: tag, data: data);

  void i(String message, {String? tag, Map<String, Object?>? data}) =>
      log(LogLevel.info, message, tag: tag, data: data);

  void w(
    String message, {
    String? tag,
    Object? error,
    Map<String, Object?>? data,
  }) =>
      log(LogLevel.warn, message, tag: tag, error: error, data: data);

  void e(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) =>
      log(
        LogLevel.error,
        message,
        tag: tag,
        error: error,
        stackTrace: stackTrace,
        data: data,
      );
}

/// Writes to the Dart developer log in debug/profile.
///
/// In release, everything below [LogLevel.warn] is dropped entirely and the rest
/// is handed to [onRelease] — which Phase 17 wires to Crashlytics.
final class ConsoleLogger implements Logger {
  const ConsoleLogger({this.onRelease});

  final void Function(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  )? onRelease;

  @override
  void log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    if (kIsReleaseBuild) {
      if (level.index >= LogLevel.warn.index) {
        onRelease?.call(level, message, error, stackTrace);
      }
      return;
    }

    final StringBuffer buffer = StringBuffer()
      ..write('[${level.name.toUpperCase()}]');
    if (tag != null) buffer.write(' [$tag]');
    buffer.write(' $message');
    if (data != null && data.isNotEmpty) buffer.write(' $data');

    developer.log(
      buffer.toString(),
      name: 'quiverfall',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Discards everything. Used by the headless balance harness, where logging
/// 10,000 simulated runs would dominate the runtime.
final class NullLogger implements Logger {
  const NullLogger();

  @override
  void log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {}
}

/// Records everything in memory so tests can assert on it.
final class RecordingLogger implements Logger {
  final List<({LogLevel level, String message, Object? error})> records =
      <({LogLevel level, String message, Object? error})>[];

  @override
  void log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    records.add((level: level, message: message, error: error));
  }

  bool hasMessageContaining(String fragment) =>
      records.any((record) => record.message.contains(fragment));

  void clear() => records.clear();
}
