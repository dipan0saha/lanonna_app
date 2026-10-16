/// User-facing label for a baby name, avoiding a duplicated "Baby" prefix.
String babyNotificationLabel(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'your baby';
  }
  if (trimmed.toLowerCase().startsWith('baby ')) {
    return trimmed;
  }
  return 'Baby $trimmed';
}
