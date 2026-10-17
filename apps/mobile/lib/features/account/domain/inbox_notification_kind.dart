/// What an inbox row is about (`notifications.notification_kind`).
///
/// Mirrors the inbox kinds of `NotificationKind` in
/// `packages/lanonna_activity_copy` (`test_feed_vocabulary_parity.py`). The
/// row's sentence is rendered from ARB (`inboxSentence`); rows written before
/// migration 038 that could not be classified have no kind and show their
/// stored text.
enum InboxNotificationKind {
  photoShared('photo_shared'),
  photoSquished('photo_squished'),
  photoCommented('photo_commented'),
  eventCreated('event_created'),
  eventRsvp('event_rsvp'),
  eventCommented('event_commented'),
  registryPurchased('registry_purchased'),
  registryBuying('registry_buying'),
  inviteAccepted('invite_accepted'),
  babyArrived('baby_arrived');

  const InboxNotificationKind(this.apiValue);

  final String apiValue;

  static InboxNotificationKind? fromApi(String? raw) {
    for (final k in values) {
      if (k.apiValue == raw) return k;
    }
    return null;
  }
}
