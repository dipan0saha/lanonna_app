import '../data/models/home_summary.dart';

/// PRD §6.2–6.3: which Home blocks appear for owners vs followers.
abstract final class HomeComposition {
  static bool hasNextUpEvent(HomeSummary summary) {
    final event = summary.nextUpEvent;
    return event != null && event.id.isNotEmpty;
  }

  /// NEXT UP card (single highlighted event). Shown for owners and followers.
  static bool showNextUpCard(HomeSummary summary) => hasNextUpEvent(summary);

  /// Upcoming-events teaser inside [HomeTeasersSection]. Hidden when NEXT UP
  /// already covers the nearest event (avoids duplicate UI for all roles).
  static bool includeUpcomingEventsTeaser(HomeSummary summary) {
    if (hasNextUpEvent(summary)) return false;
    final events = summary.teasers?.upcomingEvents;
    return events != null && events.isNotEmpty;
  }
}
