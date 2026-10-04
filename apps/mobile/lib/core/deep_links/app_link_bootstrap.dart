import 'package:app_links/app_links.dart';

import 'auth_action_app_link.dart';
import 'invite_app_link.dart';

final AppLinks _appLinks = AppLinks();

/// First deep link from cold start (invite or Firebase auth action).
Future<Uri?> readColdStartAppLinkUri() async {
  final uri = await _appLinks.getInitialLink();
  if (uri != null) return uri;
  return _appLinks.getLatestLink();
}

/// Cold-start invite URI from email (`lanonna://app/invite-accept?…`).
Future<String?> readColdStartInviteLocation() async {
  final uri = await readColdStartAppLinkUri();
  if (uri == null) return null;
  return inviteAppLinkToRouterLocation(uri);
}

/// Cold-start Firebase email verification action link.
Future<Uri?> readColdStartEmailVerifyUri() async {
  final uri = await readColdStartAppLinkUri();
  if (uri == null) return null;
  if (inviteAppLinkToRouterLocation(uri) != null) return null;
  if (parseEmailVerifyActionLink(uri) == null) return null;
  return uri;
}

/// Deep links opened while the app is already running.
Stream<Uri> watchAppLinkUris() => _appLinks.uriLinkStream;

/// Invite links opened while the app is already running.
Stream<String> watchInviteAppLinks() {
  return watchAppLinkUris()
      .map(inviteAppLinkToRouterLocation)
      .where((location) => location != null)
      .cast<String>();
}
