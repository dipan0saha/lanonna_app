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

  test('availableEventSuggestions excludes seeded first-moment gender reveal', () {
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
        title: 'Gender Reveal',
        startsAt: DateTime.utc(2027, 1, 6),
        catalogSuggestionId: 'gender_reveal',
      ),
    ];

    final available = availableEventSuggestions(catalog, events);

    expect(available.map((s) => s.id), ['baby_shower']);
  });

  test('availableEventSuggestions hides first pediatric visit after born seed', () {
    final catalog = [
      EventSuggestion(
        id: 'first_pediatric_visit',
        title: 'First pediatric visit',
        description: 'Well-baby checkup',
      ),
      EventSuggestion(
        id: 'family_meet_greet',
        title: 'Family meet & greet',
        description: 'Introduce baby',
      ),
    ];
    final events = [
      CalendarEvent(
        id: '1',
        title: 'First pediatric visit',
        startsAt: DateTime.utc(2026, 10, 23),
        catalogSuggestionId: 'first_pediatric_visit',
      ),
    ];

    final available = availableEventSuggestions(catalog, events);

    expect(available.map((s) => s.id), ['family_meet_greet']);
  });

  test('availableEventSuggestions hides catalog row when event title matches without id',
      () {
    final catalog = [
      EventSuggestion(
        id: 'gender_reveal',
        title: 'Gender reveal',
        description: 'Share news',
      ),
      EventSuggestion(
        id: 'baby_shower',
        title: 'Baby shower',
        description: 'Celebrate',
      ),
    ];
    final events = [
      CalendarEvent(
        id: '1',
        title: 'Gender Reveal',
        startsAt: DateTime.utc(2027, 1, 6),
      ),
    ];

    final available = availableEventSuggestions(catalog, events);

    expect(available.map((s) => s.id), ['baby_shower']);
  });
}
