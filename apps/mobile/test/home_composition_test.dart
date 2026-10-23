import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/domain/home_composition.dart';

void main() {
  test('includeUpcomingEventsTeaser is false when next up is set', () {
    final summary = HomeSummary(
      lifecycle: BabyLifecycle.expecting,
      nameSuggestionCount: 0,
      voteCount: 0,
      recentActivity: const [],
      nextUpEvent: const NextUpEvent(
        id: 'e1',
        title: 'Shower',
        startsAt: DateTime(2026, 1, 1),
      ),
      teasers: HomeTeasers(
        upcomingEvents: [
          NextUpEvent(
            id: 'e2',
            title: 'Tour',
            startsAt: DateTime(2026, 2, 1),
          ),
        ],
        recentPhotos: const [],
      ),
    );

    expect(HomeComposition.showNextUpCard(summary), isTrue);
    expect(HomeComposition.includeUpcomingEventsTeaser(summary), isFalse);
  });

  test('includeUpcomingEventsTeaser is true without next up', () {
    final summary = HomeSummary(
      lifecycle: BabyLifecycle.expecting,
      nameSuggestionCount: 0,
      voteCount: 0,
      recentActivity: const [],
      teasers: HomeTeasers(
        upcomingEvents: [
          NextUpEvent(
            id: 'e1',
            title: 'Tour',
            startsAt: DateTime(2026, 2, 1),
          ),
        ],
        recentPhotos: const [],
      ),
    );

    expect(HomeComposition.showNextUpCard(summary), isFalse);
    expect(HomeComposition.includeUpcomingEventsTeaser(summary), isTrue);
  });
}
