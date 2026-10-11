import 'package:app_links/app_links.dart';

final AppLinks _appLinks = AppLinks();

/// First deep link from cold start (invite or Firebase auth action).
Future<Uri?> readColdStartAppLinkUri() async {
  final uri = await _appLinks.getInitialLink();
  if (uri != null) return uri;
  return _appLinks.getLatestLink();
}

/// Deep links opened while the app is already running.
Stream<Uri> watchAppLinkUris() => _appLinks.uriLinkStream;
