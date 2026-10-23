import '../../../core/catalog/suggestion_availability.dart';
import '../data/event_suggestions_catalog.dart';
import '../data/models/calendar_models.dart';

Set<String> claimedEventCatalogSuggestionIds(
  List<EventSuggestion> catalog,
  Iterable<CalendarEvent> events,
) =>
    claimedCatalogIdsWithTitleFallback<EventSuggestion, CalendarEvent>(
      catalog: catalog,
      existing: events,
      catalogIdForExisting: (e) => e.catalogSuggestionId,
      titleForExisting: (e) => e.title,
      idForCatalog: (s) => s.id,
      titleForCatalog: (s) => s.title,
    );

List<EventSuggestion> availableEventSuggestions(
  List<EventSuggestion> catalog,
  Iterable<CalendarEvent> events,
) {
  final claimed = claimedEventCatalogSuggestionIds(catalog, events);
  return excludingClaimedIds(
    catalog: catalog,
    claimedIds: claimed,
    idFor: (s) => s.id,
  );
}
