import '../data/models/home_summary.dart';

/// PRD §6.2–6.3 / prototype: where Home shows upcoming events, for owners
/// and followers alike. Expecting Home has a NEXT UP card for the nearest
/// event; born Home has no NEXT UP card, so the upcoming-events teaser strip
/// is its only events surface. The teaser strip is hidden only when NEXT UP
/// is actually rendered, so no role or lifecycle loses its events (#394).
abstract final class HomeComposition {
  static bool _hasNextUpEvent(HomeSummary summary) {
    final event = summary.nextUpEvent;
    return event != null && event.id.isNotEmpty;
  }

  /// NEXT UP card (single highlighted event) on expecting Home.
  static bool showNextUpCard(HomeSummary summary) =>
      !summary.isBorn && _hasNextUpEvent(summary);

  /// Upcoming-events strip inside the teasers section, unless NEXT UP
  /// already covers the nearest event.
  static bool includeUpcomingEventsTeaser(HomeSummary summary) =>
      !showNextUpCard(summary);
}
