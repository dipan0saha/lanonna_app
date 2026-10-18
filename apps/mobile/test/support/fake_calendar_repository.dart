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
  List<CalendarEvent> monthEvents = const [];

  /// `cover_photo_id` of each [createEvent] / [updateEvent] call, in order.
  final createdCoverIds = <String?>[];
  final updatedCoverIds = <String?>[];

  /// Thrown (once) by the next create or update, to test a failed save.
  Object? nextSaveError;

  CalendarEvent _saved(String title, DateTime startsAt, String? coverPhotoId) {
    final error = nextSaveError;
    if (error != null) {
      nextSaveError = null;
      throw error;
    }
    return CalendarEvent(
      id: 'ev-saved',
      title: title,
      startsAt: startsAt,
      coverPhotoId: coverPhotoId,
    );
  }

  @override
  Future<CalendarEvent> createEvent(
    String babyId, {
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? description,
    String? location,
    String? videoCallUrl,
    String? coverPhotoId,
    String? catalogSuggestionId,
  }) async {
    createdCoverIds.add(coverPhotoId);
    return _saved(title, startsAt, coverPhotoId);
  }

  @override
  Future<CalendarEvent> updateEvent(
    String babyId,
    String eventId, {
    required String title,
    required DateTime startsAt,
    required String? description,
    required String? location,
    required String? videoCallUrl,
    required String? coverPhotoId,
  }) async {
    updatedCoverIds.add(coverPhotoId);
    return _saved(title, startsAt, coverPhotoId);
  }

  @override
  Future<List<CalendarEvent>> listEvents(
    String babyId, {
    String? month,
    bool upcoming = false,
    bool forceRefresh = false,
  }) async {
    listCalls++;
    if (upcoming) return upcomingEvents;
    if (month != null) return monthEvents;
    return upcomingEvents;
  }

  @override
  Future<List<CalendarEvent>> listEventsForSuggestionDedupe(
    String babyId,
  ) async {
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
