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
        'show_rich_insight': true,
      },
      'teasers': {
        'recent_photos': [
          {'id': 'p1', 'thumb_url': 'https://thumb'},
        ],
        'upcoming_events': [
          {'id': 'e1', 'title': 'Shower', 'starts_at': '2026-10-02T18:00:00Z'},
        ],
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
    expect(summary.teasers?.recentPhotos.single.id, 'p1');
    expect(summary.teasers?.upcomingEvents.single.title, 'Shower');
    expect(summary.recentActivity, hasLength(1));
    expect(summary.recentActivity.first.eventType, 'registry_item_added');
    expect(summary.showRichInsight, isTrue);
  });

  test('showRichInsight false when only owner name suggestions exist', () {
    final summary = HomeSummary.fromJson({
      'lifecycle_status': 'expecting',
      'family_insight': {
        'name_suggestion_count': 2,
        'vote_count': 0,
        'top_name': {'suggested_name': 'Olivia', 'like_count': 0},
        'show_rich_insight': false,
      },
    });
    expect(summary.showRichInsight, isFalse);
  });

  test('showRichInsight reads the server flag (votes)', () {
    final summary = HomeSummary.fromJson({
      'lifecycle_status': 'expecting',
      'family_insight': {
        'name_suggestion_count': 0,
        'vote_count': 1,
        'show_rich_insight': true,
      },
    });
    expect(summary.showRichInsight, isTrue);
  });

  test('showRichInsight reads the server flag (loves)', () {
    final summary = HomeSummary.fromJson({
      'lifecycle_status': 'expecting',
      'family_insight': {
        'name_suggestion_count': 1,
        'vote_count': 0,
        'top_name': {'suggested_name': 'Milo', 'like_count': 1},
        'show_rich_insight': true,
      },
    });
    expect(summary.showRichInsight, isTrue);
  });
}
