/// The app's only `mailto:` builder (RFC 6068, #419).
///
/// `Uri(queryParameters: …)` applies form encoding (`+` for spaces), which
/// mail clients show literally in the subject, so the query is built with
/// [Uri.encodeComponent] (`%20`) instead.
Uri buildMailtoUri({required String address, String? subject}) {
  return Uri(
    scheme: 'mailto',
    path: address,
    query: subject == null || subject.isEmpty
        ? null
        : 'subject=${Uri.encodeComponent(subject)}',
  );
}
