/// Keys of the `params` object on activity rows and inbox notifications.
///
/// Mirrors `lanonna_activity_copy/params.py` (`test_feed_vocabulary_parity.py`
/// keeps them in sync). Values are display strings captured when the event
/// happened; people are never stored here (names come back as
/// `actor_display_name` / `target_display_name`).
abstract final class FeedParam {
  static const caption = 'caption';
  static const itemName = 'item_name';
  static const eventTitle = 'event_title';
  static const suggestedName = 'suggested_name';
  static const gender = 'gender';
  static const babyName = 'baby_name';
  static const rsvpStatus = 'rsvp_status';
}

/// String-valued `params` from an API row; anything else is dropped.
Map<String, String> readFeedParams(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value is String) entry.key.toString(): entry.value as String,
  };
}

extension FeedParamsRead on Map<String, String> {
  /// Trimmed value, or `null` when missing or blank.
  String? text(String key) {
    final value = this[key]?.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}
