/// Server-owned activity feed event (`activity_events.event_type`).
///
/// Mirrors `ActivityEventType` in `packages/lanonna_activity_copy`
/// (`test_feed_vocabulary_parity.py` keeps them in sync). The app renders each
/// row from ARB (`activitySentence`); the row's English `summary` is only shown
/// for a type this build does not know.
enum ActivityEventType {
  photoShared('photo_shared'),
  photoSquish('photo_squish'),
  photoComment('photo_comment'),
  registryItemAdded('registry_item_added'),

  /// An owner marked an item purchased (named in the feed).
  registryPurchased('registry_purchased'),

  /// A follower claimed an item; the buyer stays anonymous.
  registryClaimed('registry_claimed'),
  eventCreated('event_created'),
  nameSuggested('name_suggested'),
  genderVoteCast('gender_vote_cast'),
  babyArrived('baby_arrived'),
  memberRemoved('member_removed'),
  memberLeft('member_left');

  const ActivityEventType(this.apiValue);

  final String apiValue;

  /// Unknown values (a newer server) are `null`; callers show the summary.
  static ActivityEventType? fromApi(String? raw) {
    for (final t in values) {
      if (t.apiValue == raw) return t;
    }
    return null;
  }
}
