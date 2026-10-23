import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Keepsake card location for [babyId].
String announcementCardLocation(String babyId) => '/baby/$babyId/announcement';

/// Create/edit form location for [babyId].
String announcementCreateLocation(String babyId) =>
    '/baby/$babyId/announcement/create';

/// After Save Announcement, show the card without dropping the route under the form.
///
/// Edit is pushed on top of the card, so save pops back to that card.
/// Create is pushed on top of Home (or replaces an empty card), so save
/// replaces the form with the card and leaves Home underneath.
void showAnnouncementCardAfterSave(BuildContext context, String babyId) {
  final card = announcementCardLocation(babyId);
  final matches =
      GoRouter.of(context).routerDelegate.currentConfiguration.matches;
  if (matches.length >= 2 && matches[matches.length - 2].matchedLocation == card) {
    context.pop();
    return;
  }
  context.pushReplacement(card);
}
