import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';

void main() {
  test('HomeSummary.fromJson parses teasers, activity, and numeric fields', () {
    final summary = HomeSummary.fromJson({
      'lifecycle_status': 'expecting',
      'days_to_due': 42.0,
      'family_insight': {
        'name_suggestion_count': 3,
        'vote_count': 7,
        'gender_totals': {'male': 4.0, 'female': 3},
        'top_name': {'suggested_name': 'Milo', 'like_count': 5},
      },
      'teasers': {
        'recent_photos': [],
        'favorite_photos': [],
        'registry_open_count': 2,
        'registry_highlights': [
          {'id': 'r1', 'name': 'Stroller', 'priority': 1.0},
        ],
        'recent_registry_purchases': [],
        'upcoming_events': [],
        'rsvp_reminders': [],
        'notification_preview': [],
      },
      'recent_activity': [
        {
          'id': 'evt-1',
          'event_type': 'registry_item_added',
          'summary': 'Added stroller',
          'created_at': '2026-10-01T12:00:00Z',
        },
      ],
    });

    expect(summary.daysToDue, 42);
    expect(summary.nameSuggestionCount, 3);
    expect(summary.voteCount, 7);
    expect(summary.genderTotals?.male, 4);
    expect(summary.topName?.likeCount, 5);
    expect(summary.teasers?.registryOpenCount, 2);
    expect(summary.teasers?.registryHighlights.single.name, 'Stroller');
    expect(summary.recentActivity, hasLength(1));
    expect(summary.recentActivity.first.eventType, 'registry_item_added');
  });
}
