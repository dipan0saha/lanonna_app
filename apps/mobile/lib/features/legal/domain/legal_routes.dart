/// In-app legal document routes (bundled HTML in WebView).
abstract final class LegalRoutes {
  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';

  static const Set<String> paths = {terms, privacy};
}
