/// Builds [mailto] URIs per RFC 6068.
///
/// Use this instead of [Uri.queryParameters], which applies form encoding
/// (`+` for spaces) that many mail clients show literally in the subject.
Uri buildMailtoUri({
  required String address,
  String? subject,
  String? body,
}) {
  final queryParts = <String>[];
  if (subject != null && subject.isNotEmpty) {
    queryParts.add('subject=${Uri.encodeComponent(subject)}');
  }
  if (body != null && body.isNotEmpty) {
    queryParts.add('body=${Uri.encodeComponent(body)}');
  }
  return Uri(
    scheme: 'mailto',
    path: address,
    query: queryParts.isEmpty ? null : queryParts.join('&'),
  );
}
