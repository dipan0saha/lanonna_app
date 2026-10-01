import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import 'models/calendar_models.dart';

class CalendarRepository extends ChangeNotifier {
  CalendarRepository(this._api);

  final ApiClient _api;

  void _markEventsChanged() => notifyListeners();

  Future<List<CalendarEvent>> listEvents(
    String babyId, {
    String? month,
    bool upcoming = false,
  }) async {
    final query = <String>[];
    if (month != null) query.add('month=$month');
    if (upcoming) query.add('upcoming=true');
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';
    final list =
        await _api.getJsonList('/v1/babies/$babyId/events$suffix');
    return list
        .whereType<Map<String, dynamic>>()
        .map(CalendarEvent.fromJson)
        .toList();
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
  }) async {
    final json = await _api.postJson('/v1/babies/$babyId/events', body: {
      'title': title,
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (videoCallUrl != null) 'video_call_url': videoCallUrl,
      if (coverPhotoId != null) 'cover_photo_id': coverPhotoId,
    });
    final event = CalendarEvent.fromJson(json);
    _markEventsChanged();
    return event;
  }

  Future<CalendarEvent> updateEvent(
    String babyId,
    String eventId, {
    String? title,
    DateTime? startsAt,
    DateTime? endsAt,
    String? description,
    String? location,
    String? videoCallUrl,
    String? coverPhotoId,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (startsAt != null) body['starts_at'] = startsAt.toUtc().toIso8601String();
    if (endsAt != null) body['ends_at'] = endsAt.toUtc().toIso8601String();
    if (description != null) body['description'] = description;
    if (location != null) body['location'] = location;
    if (videoCallUrl != null) body['video_call_url'] = videoCallUrl;
    if (coverPhotoId != null) body['cover_photo_id'] = coverPhotoId;
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

  Future<String> setRsvp(String babyId, String eventId, String status) async {
    final json = await _api.putJson(
      '/v1/babies/$babyId/events/$eventId/rsvp',
      body: {'status': status},
    );
    return json['status'] as String? ?? status;
  }

  Future<void> addComment(String babyId, String eventId, String body) async {
    await _api.postJson('/v1/babies/$babyId/events/$eventId/comments', body: {
      'body': body,
    });
  }
}
