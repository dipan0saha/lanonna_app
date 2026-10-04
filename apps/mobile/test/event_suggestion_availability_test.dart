import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/calendar/data/event_suggestions_catalog.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/features/calendar/domain/event_suggestion_availability.dart';

void main() {
  test('availableEventSuggestions excludes claimed catalog ids', () {
    final catalog = [
      EventSuggestion(
        id: 'baby_shower',
        title: 'Baby shower',
        description: 'Celebrate',
      ),
      EventSuggestion(
        id: 'gender_reveal',
        title: 'Gender reveal',
        description: 'Share news',
      ),
    ];
    final events = [
      CalendarEvent(
        id: '1',
        title: 'Baby shower',
        startsAt: DateTime.utc(2026, 1, 1),
        catalogSuggestionId: 'baby_shower',
      ),
    ];

    final available = availableEventSuggestions(catalog, events);

    expect(available.map((s) => s.id), ['gender_reveal']);
  });
}
