/// User-facing reference to a baby in copy: the name exactly as the owner
/// entered it (never prefixed, so "Baby Parker" stays "Baby Parker"), or a
/// neutral fallback while the name is unknown.
String babyDisplayName(String? name) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? 'your baby' : trimmed;
}
