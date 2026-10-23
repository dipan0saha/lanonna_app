import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/domain/home_composition.dart';

HomeSummary _summary({
  required BabyLifecycle lifecycle,
  required bool withNextUp,
}) {
  final event = NextUpEvent(
    id: 'e1',
    title: 'Shower',
    startsAt: DateTime(2026, 1, 1),
  );
  return HomeSummary(
    lifecycle: lifecycle,
    nameSuggestionCount: 0,
    voteCount: 0,
    recentActivity: const [],
    nextUpEvent: withNextUp ? event : null,
    teasers: HomeTeasers(upcomingEvents: [event], recentPhotos: const []),
  );
}

void main() {
  test('expecting with next up: NEXT UP card, no duplicate teaser strip', () {
    final s = _summary(lifecycle: BabyLifecycle.expecting, withNextUp: true);
    expect(HomeComposition.showNextUpCard(s), isTrue);
    expect(HomeComposition.includeUpcomingEventsTeaser(s), isFalse);
  });

  test('expecting without next up: teaser strip only', () {
    final s = _summary(lifecycle: BabyLifecycle.expecting, withNextUp: false);
    expect(HomeComposition.showNextUpCard(s), isFalse);
    expect(HomeComposition.includeUpcomingEventsTeaser(s), isTrue);
  });

  test('born with next up keeps the teaser strip (no NEXT UP on born Home)', () {
    final s = _summary(lifecycle: BabyLifecycle.born, withNextUp: true);
    expect(HomeComposition.showNextUpCard(s), isFalse);
    expect(HomeComposition.includeUpcomingEventsTeaser(s), isTrue);
  });
}
