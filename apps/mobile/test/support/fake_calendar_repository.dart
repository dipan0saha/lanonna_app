import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';

/// Offline [CalendarRepository].
///
/// `listEvents` returns [upcomingEvents]; `fetchEvent` builds a detail with [detailByFetch]
/// (a test that never fetches an event can omit it). Both count their calls.
class FakeCalendarRepository extends CalendarRepository {
  FakeCalendarRepository({this.detailByFetch})
      : super(ApiClient(idTokenProvider: () async => null));

  final EventDetail Function()? detailByFetch;

  int listCalls = 0;
  int fetchCalls = 0;
  List<CalendarEvent> upcomingEvents = const [];

  @override
  Future<List<CalendarEvent>> listEvents(
    String babyId, {
    String? month,
    bool upcoming = false,
    bool forceRefresh = false,
  }) async {
    listCalls++;
    return upcomingEvents;
  }

  @override
  Future<List<CalendarEvent>> listEventsForSuggestionDedupe(String babyId) async {
    listCalls++;
    return upcomingEvents;
  }

  @override
  Future<EventDetail> fetchEvent(String babyId, String eventId) async {
    fetchCalls++;
    final build = detailByFetch;
    if (build == null) {
      throw StateError('FakeCalendarRepository.fetchEvent needs detailByFetch');
    }
    return build();
  }
}
