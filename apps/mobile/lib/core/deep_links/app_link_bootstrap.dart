import 'package:app_links/app_links.dart';

import 'invite_app_link.dart';

final AppLinks _appLinks = AppLinks();

/// Cold-start invite URI from email (`lanonna://app/invite-accept?…`).
Future<String?> readColdStartInviteLocation() async {
  final uri = await _appLinks.getInitialLink();
  if (uri != null) {
    final location = inviteAppLinkToRouterLocation(uri);
    if (location != null) return location;
  }
  final latest = await _appLinks.getLatestLink();
  if (latest != null) {
    return inviteAppLinkToRouterLocation(latest);
  }
  return null;
}

/// Invite links opened while the app is already running.
Stream<String> watchInviteAppLinks() {
  return _appLinks.uriLinkStream
      .map(inviteAppLinkToRouterLocation)
      .where((location) => location != null)
      .cast<String>();
}
