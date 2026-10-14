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

  @override
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    calls++;
    if (failRequests) {
      throw const SocketException('offline');
    }
    return [
      {
        'id': 'ev-1',
        'title': 'March event',
        'starts_at': '2026-03-10T12:00:00Z',
      },
    ];
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
}

class _DedupeEventsApi extends ApiClient {
  _DedupeEventsApi() : super(idTokenProvider: () async => 'token');

  var monthCalls = 0;
  var upcomingCalls = 0;

  @override
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    if (path.contains('upcoming=true')) {
      upcomingCalls++;
      return [
        {
          'id': 'u1',
          'title': 'Upcoming',
          'starts_at': '2026-12-01T12:00:00Z',
        },
      ];
    }
    monthCalls++;
    return [
      {
        'id': 'm1',
        'title': 'Month',
        'starts_at': '2026-03-01T12:00:00Z',
      },
    ];
  }
}
