import '../../../core/catalog/suggestion_availability.dart';
import '../data/event_suggestions_catalog.dart';
import '../data/models/calendar_models.dart';

Set<String> claimedEventCatalogSuggestionIds(Iterable<CalendarEvent> events) =>
    claimedIdsFromNullable(events.map((e) => e.catalogSuggestionId));

List<EventSuggestion> availableEventSuggestions(
  List<EventSuggestion> catalog,
  Iterable<CalendarEvent> events,
) {
  final claimed = claimedEventCatalogSuggestionIds(events);
  return excludingClaimedIds(
    catalog: catalog,
    claimedIds: claimed,
    idFor: (s) => s.id,
  );
}
