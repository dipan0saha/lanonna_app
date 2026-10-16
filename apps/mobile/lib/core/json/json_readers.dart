import 'package:flutter/foundation.dart';

/// Safe JSON field readers for API payloads.
int readInt(
  Object? value, {
  int defaultValue = 0,
  bool strict = false,
  String? field,
}) {
  if (value == null) {
    if (strict) {
      throw FormatException('Missing integer field${field != null ? ' $field' : ''}');
    }
    return defaultValue;
  }
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (strict) {
    throw FormatException(
      'Expected integer${field != null ? ' for $field' : ''}, got $value',
    );
  }
  if (kDebugMode) {
    debugPrint('readInt_coercion field=${field ?? '?'} value=$value');
  }
  return defaultValue;
}
