/// Up to two uppercase initials for an avatar: first letters of the first two words of
/// [name], or of [fallbackText] (e.g. an email) when [name] is blank.
///
/// Returns [emptyFallback] when both are blank.
String displayInitials(
  String? name, {
  String? fallbackText,
  String emptyFallback = '?',
}) {
  final primary = name?.trim() ?? '';
  final source = primary.isNotEmpty ? primary : (fallbackText?.trim() ?? '');
  if (source.isEmpty) return emptyFallback;
  final parts = source.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return source[0].toUpperCase();
}
