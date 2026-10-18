import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';

void main() {
  test('listEvents caches by baby and month key', () async {
    final api = _EventsApi();
    final repo = CalendarRepository(api);
    final first = await repo.listEvents('baby-1', month: '2026-03');
    expect(first, hasLength(1));
    expect(first.first.title, 'March event');
    expect(api.calls, 1);
    expect(api.lastPath, contains('starts_from='));
    expect(api.lastPath, contains('starts_before='));
    expect(api.lastPath, isNot(contains('month=')));

    final cached = await repo.listEvents('baby-1', month: '2026-03');
    expect(cached.first.title, first.first.title);
    expect(api.calls, 1);

    expect(
      repo.peekCachedEvents('baby-1', month: '2026-03')?.first.title,
      'March event',
    );
  });

  test('listEvents serves stale month cache on network failure', () async {
    final api = _EventsApi();
    final repo = CalendarRepository(api);
    await repo.listEvents('baby-1', month: '2026-03');
    api.failRequests = true;
    final offline = await repo.listEvents('baby-1', month: '2026-03');
    expect(offline.first.title, 'March event');
  });

  test('mutations clear event list cache', () async {
    final api = _EventsApi();
    final repo = CalendarRepository(api);
    await repo.listEvents('baby-1', month: '2026-03');
    await repo.createEvent(
      'baby-1',
      title: 'New',
      startsAt: DateTime.utc(2026, 3, 10),
    );
    expect(repo.peekCachedEvents('baby-1', month: '2026-03'), isNull);
    await repo.listEvents('baby-1', month: '2026-03');
    expect(api.calls, 2);
  });

  test('updateEvent sends cleared optional fields as explicit nulls', () async {
    final api = _EventsApi();
    final repo = CalendarRepository(api);
    await repo.updateEvent(
      'baby-1',
      'ev-1',
      title: 'Edited',
      startsAt: DateTime.utc(2026, 3, 10),
      description: null,
      location: null,
      videoCallUrl: null,
      coverPhotoId: null,
    );
    expect(api.lastPatchPath, '/v1/babies/baby-1/events/ev-1');
    final body = api.lastPatchBody!;
    for (final key in [
      'description',
      'location',
      'video_call_url',
      'cover_photo_id',
    ]) {
      expect(body.containsKey(key), isTrue, reason: '$key must be sent');
      expect(body[key], isNull);
    }
    expect(body['title'], 'Edited');
  });

  test('listEventsForSuggestionDedupe merges month and upcoming', () async {
    final api = _DedupeEventsApi();
    final repo = CalendarRepository(api);
    final events = await repo.listEventsForSuggestionDedupe('baby-1');
    expect(events.map((e) => e.id).toSet(), {'m1', 'u1'});
    expect(api.monthCalls, greaterThan(0));
    expect(api.upcomingCalls, greaterThan(0));
  });
}

class _EventsApi extends ApiClient {
  _EventsApi() : super(idTokenProvider: () async => 'token');

  var failRequests = false;
  var calls = 0;
  String? lastPath;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    lastPath = path;
    calls++;
    if (failRequests) {
      throw const SocketException('offline');
    }
    return _page([
      {
        'id': 'ev-1',
        'title': 'March event',
        'starts_at': '2026-03-10T12:00:00Z',
      },
      ]);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return {
      'id': 'ev-new',
      'title': body?['title'],
      'starts_at': body?['starts_at'],
    };
  }

  String? lastPatchPath;
  Map<String, dynamic>? lastPatchBody;

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    lastPatchPath = path;
    lastPatchBody = body;
    return {
      'id': 'ev-1',
      'title': body?['title'],
      'starts_at': body?['starts_at'],
    };
  }
}

class _DedupeEventsApi extends ApiClient {
  _DedupeEventsApi() : super(idTokenProvider: () async => 'token');

  var monthCalls = 0;
  var upcomingCalls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    if (path.contains('upcoming=true')) {
      upcomingCalls++;
      return _page([
        {
          'id': 'u1',
          'title': 'Upcoming',
          'starts_at': '2026-12-01T12:00:00Z',
        },
        ]);
    }
    monthCalls++;
    return _page([
      {
        'id': 'm1',
        'title': 'Month',
        'starts_at': '2026-03-01T12:00:00Z',
      },
      ]);
  }
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
  'items': items,
  'offset': 0,
  'limit': items.length,
  'has_more': false,
};
