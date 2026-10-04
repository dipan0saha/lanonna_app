/// Safe JSON field readers for API payloads.
int readInt(Object? value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return defaultValue;
}
