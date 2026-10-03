import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Registro ya redactado, listo para escribirse.
class LogRecord {
  const LogRecord({
    required this.level,
    required this.logger,
    required this.message,
    this.fields = const {},
    this.error,
    this.stackTrace,
  });

  final LogLevel level;
  final String logger;
  final String message;
  final Map<String, Object?> fields;
  final String? error;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('[${level.name.toUpperCase()}] $logger: ')
      ..write(message);
    if (fields.isNotEmpty) {
      buffer
        ..write(' ')
        ..write(fields.entries.map((e) => '${e.key}=${e.value}').join(' '));
    }
    if (error != null) buffer.write(' error=$error');
    return buffer.toString();
  }
}

typedef LogSink = void Function(LogRecord record);

/// Logger estructurado que redacta PII antes de escribir (FR-034).
///
/// Enmascara correos, montos y secuencias de 8 o más dígitos en el mensaje,
/// en los valores de los campos y en el texto del error; además oculta por
/// completo los campos cuyo nombre indica un dato sensible.
class AppLogger {
  AppLogger(this.name, {LogSink? sink, this.minLevel = _defaultMinLevel})
    : _sink = sink ?? _developerSink;

  static const _defaultMinLevel = kReleaseMode ? LogLevel.info : LogLevel.debug;

  static const redactedEmail = '[email]';
  static const redactedAmount = '[monto]';
  static const redactedNumber = '[numero]';
  static const redactedValue = '[redactado]';

  static final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
  static final _longNumber = RegExp(r'\d{8,}');
  static final _currencyAmount = RegExp(
    r'(US\$|\$|USD|EUR)\s?-?\d[\d.,]*',
    caseSensitive: false,
  );
  static final _decimalAmount = RegExp(r'\b\d{1,3}(?:[.,]\d{3})*[.,]\d{2}\b');
  static final _sensitiveKey = RegExp(
    'email|correo|password|contrasena|name|nombre|amount|monto|balance|saldo'
    '|cents|number|numero|token',
    caseSensitive: false,
  );

  final String name;
  final LogLevel minLevel;
  final LogSink _sink;

  /// Reemplaza la PII detectable en [input].
  static String redact(String input) {
    return input
        .replaceAll(_email, redactedEmail)
        .replaceAll(_currencyAmount, redactedAmount)
        .replaceAll(_decimalAmount, redactedAmount)
        .replaceAll(_longNumber, redactedNumber);
  }

  static Map<String, Object?> redactFields(Map<String, Object?> fields) {
    return {
      for (final entry in fields.entries)
        entry.key: _sensitiveKey.hasMatch(entry.key)
            ? redactedValue
            : _redactValue(entry.value),
    };
  }

  static Object? _redactValue(Object? value) {
    if (value == null || value is bool) return value;
    return redact(value.toString());
  }

  void debug(String message, [Map<String, Object?> fields = const {}]) =>
      _log(LogLevel.debug, message, fields);

  void info(String message, [Map<String, Object?> fields = const {}]) =>
      _log(LogLevel.info, message, fields);

  void warning(String message, [Map<String, Object?> fields = const {}]) =>
      _log(LogLevel.warning, message, fields);

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => _log(LogLevel.error, message, fields, error, stackTrace);

  void _log(
    LogLevel level,
    String message,
    Map<String, Object?> fields, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (level.index < minLevel.index) return;
    _sink(
      LogRecord(
        level: level,
        logger: name,
        message: redact(message),
        fields: redactFields(fields),
        error: error == null ? null : redact(error.toString()),
        stackTrace: stackTrace,
      ),
    );
  }

  static void _developerSink(LogRecord record) {
    developer.log(
      record.toString(),
      name: record.logger,
      level: switch (record.level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      stackTrace: record.stackTrace,
    );
  }
}
