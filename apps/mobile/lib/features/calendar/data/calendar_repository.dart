import 'package:flutter/foundation.dart';
import 'package:lanonna/core/domain/rsvp_status.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/offset_page.dart';
import '../../../core/time/app_date_time.dart';
import '../domain/calendar_event_lists.dart';
import 'models/calendar_models.dart';

class CalendarPastEventsPage {
  CalendarPastEventsPage({
    required this.items,
    required this.hasMore,
    required this.offset,
    required this.limit,
  });

  final List<CalendarEvent> items;
  final bool hasMore;
  final int offset;
  final int limit;
}

class CalendarRepository extends ChangeNotifier {
  CalendarRepository(this._api);

  final ApiClient _api;

  final Map<String, Map<String, List<CalendarEvent>>> _listsByBaby = {};

  void _markEventsChanged() {
    _listsByBaby.clear();
    notifyListeners();
  }

  /// Sign-out / account deletion: drop every cached event list.
  void clearCachedEvents() => _listsByBaby.clear();

  static String _cacheKey({String? month, bool upcoming = false}) {
    if (upcoming) return 'upcoming';
    return 'month:$month';
  }

  static bool _shouldServeStaleListCache(Object error) {
    if (error is ApiException) {
      final code = error.statusCode;
      if (code != null && code >= 400 && code < 500) {
        return false;
      }
    }
    return true;
  }

  List<CalendarEvent>? peekCachedEvents(
    String babyId, {
    String? month,
    bool upcoming = false,
  }) {
    return _listsByBaby[babyId]?[_cacheKey(month: month, upcoming: upcoming)];
  }

  Future<CalendarPastEventsPage> listPastEventsPage(
    String babyId, {
    int offset = 0,
    int? limit,
  }) async {
    final pageLimit = limit ?? 30;
    final json = await _api.getJson(
      '/v1/babies/$babyId/events?past=true&offset=$offset&limit=$pageLimit',
    );
    final page = parseOffsetPage(
      json,
      CalendarEvent.fromJson,
      defaultLimit: pageLimit,
    );
    return CalendarPastEventsPage(
      items: page.items,
      hasMore: page.hasMore,
      offset: page.offset,
      limit: page.limit,
    );
  }

  Future<List<CalendarEvent>> listEvents(
    String babyId, {
    String? month,
    bool upcoming = false,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(month: month, upcoming: upcoming);
    if (!forceRefresh) {
      final cached = _listsByBaby[babyId]?[key];
      if (cached != null) return cached;
    }
    try {
      final query = <String>[];
      if (month != null) query.add('month=$month');
      if (upcoming) query.add('upcoming=true');
      final suffix = query.isEmpty ? '' : '?${query.join('&')}';
      final json = await _api.getJson('/v1/babies/$babyId/events$suffix');
      final events = parseOffsetPage(json, CalendarEvent.fromJson).items;
      final babyCache = _listsByBaby.putIfAbsent(babyId, () => {});
      babyCache[key] = events;
      return events;
    } catch (e) {
      final cached = _listsByBaby[babyId]?[key];
      if (cached != null && _shouldServeStaleListCache(e)) {
        return cached;
      }
      rethrow;
    }
  }

  /// Catalog dedupe: current calendar month plus upcoming (not full history).
  Future<List<CalendarEvent>> listEventsForSuggestionDedupe(String babyId) async {
    final now = DateTime.now();
    final currentKey = calendarMonthKey(now);
    final month = await listEvents(babyId, month: currentKey);
    final upcoming = await listEvents(babyId, upcoming: true);
    final byId = <String, CalendarEvent>{};
    for (final event in [...month, ...upcoming]) {
      byId[event.id] = event;
    }
    return byId.values.toList();
  }

  Future<EventDetail> fetchEvent(String babyId, String eventId) async {
    final json = await _api.getJson('/v1/babies/$babyId/events/$eventId');
    return EventDetail.fromJson(json);
  }

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
    final json = await _api.postJson('/v1/babies/$babyId/events', body: {
      'title': title,
      'starts_at': toApiInstant(startsAt),
      if (endsAt != null) 'ends_at': toApiInstant(endsAt),
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (videoCallUrl != null) 'video_call_url': videoCallUrl,
      if (coverPhotoId != null) 'cover_photo_id': coverPhotoId,
      if (catalogSuggestionId != null)
        'catalog_suggestion_id': catalogSuggestionId,
    });
    final event = CalendarEvent.fromJson(json);
    _markEventsChanged();
    return event;
  }

  /// Saves the edit form. Every form field is sent, and `null` clears an
  /// optional one (description, location, video link, cover photo); the API
  /// treats a missing key as "unchanged".
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
    final body = <String, dynamic>{
      'title': title,
      'starts_at': toApiInstant(startsAt),
      'description': description,
      'location': location,
      'video_call_url': videoCallUrl,
      'cover_photo_id': coverPhotoId,
    };
    final json =
        await _api.patchJson('/v1/babies/$babyId/events/$eventId', body: body);
    final event = CalendarEvent.fromJson(json);
    _markEventsChanged();
    return event;
  }

  Future<void> deleteEvent(String babyId, String eventId) async {
    await _api.deleteJson('/v1/babies/$babyId/events/$eventId');
    _markEventsChanged();
  }

  Future<void> setRsvp(
    String babyId,
    String eventId,
    RsvpStatus status,
  ) async {
    await _api.putJson(
      '/v1/babies/$babyId/events/$eventId/rsvp',
      body: {'status': status.apiValue},
    );
  }

  Future<void> addComment(String babyId, String eventId, String body) async {
    await _api.postJson('/v1/babies/$babyId/events/$eventId/comments', body: {
      'body': body,
    });
  }

  Future<void> deleteComment(
    String babyId,
    String eventId,
    String commentId,
  ) async {
    await _api.deleteJson(
      '/v1/babies/$babyId/events/$eventId/comments/$commentId',
    );
  }

  Future<void> updateComment(
    String babyId,
    String eventId,
    String commentId,
    String body,
  ) async {
    await _api.patchJson(
      '/v1/babies/$babyId/events/$eventId/comments/$commentId',
      body: {'body': body},
    );
  }
}
