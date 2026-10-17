import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/domain/baby_display_label.dart';
import '../../../../core/domain/feed_params.dart';
import '../../../../core/domain/person_display_label.dart';
import '../../../../core/widgets/activity/feed_sentence.dart';
import '../../data/notifications_repository.dart';
import '../../domain/inbox_notification_kind.dart';

/// The ARB sentence for one inbox row.
///
/// Rows with no kind (written before migration 038 and not classifiable) or
/// missing a value their sentence needs show the push text the worker stored.
FeedSentence inboxSentence(AppLocalizations l10n, InboxNotification n) {
  final params = n.params;
  final actor = personDisplayName(l10n, n.actorDisplayName);
  final title = params.text(FeedParam.eventTitle);
  final itemName = params.text(FeedParam.itemName);
  final babyName = params.text(FeedParam.babyName);

  FeedSentence byActor(String Function(String actor) message) =>
      FeedSentence((t) => message(t[0]), [actor]);

  return switch (n.kind) {
    InboxNotificationKind.photoShared => byActor(l10n.inboxPhotoShared),
    InboxNotificationKind.photoSquished => byActor(l10n.inboxPhotoSquished),
    InboxNotificationKind.photoCommented => byActor(l10n.inboxPhotoCommented),
    InboxNotificationKind.eventCreated when title != null =>
      byActor((a) => l10n.inboxEventCreated(a, title)),
    InboxNotificationKind.eventRsvp when title != null => byActor(
        (a) => l10n.inboxEventRsvp(
          a,
          title,
          params.text(FeedParam.rsvpStatus) ?? '',
        ),
      ),
    InboxNotificationKind.eventCommented when title != null =>
      byActor((a) => l10n.inboxEventCommented(a, title)),
    InboxNotificationKind.registryPurchased when itemName != null =>
      byActor((a) => l10n.inboxRegistryPurchased(a, itemName)),
    InboxNotificationKind.registryBuying when itemName != null =>
      byActor((a) => l10n.inboxRegistryBuying(a, itemName)),
    InboxNotificationKind.inviteAccepted => byActor(
        (a) => l10n.inboxInviteAccepted(a, babyDisplayName(l10n, babyName)),
      ),
    InboxNotificationKind.babyArrived => FeedSentence(
        (_) => l10n.inboxBabyArrived(babyName ?? l10n.babyNameDefault),
      ),
    _ => FeedSentence.stored(_storedText(l10n, n)),
  };
}

String _storedText(AppLocalizations l10n, InboxNotification n) {
  final body = n.body.trim();
  if (body.isNotEmpty) return body;
  final title = n.title.trim();
  if (title.isNotEmpty) return title;
  return l10n.inboxNotificationFallbackTitle;
}
