import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/data/baby_list_cache.dart';

/// Counts `GET /v1/babies` calls; each can be gated, failed or answered.
class _BabiesApi extends ApiClient {
  _BabiesApi() : super(idTokenProvider: () async => 'token');

  var calls = 0;
  Object? failWith;
  Completer<void>? gate;
  List<String> ids = ['baby-a', 'baby-b'];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    expect(path, startsWith('/v1/babies?'));
    calls++;
    final snapshot = List.of(ids);
    final pending = gate;
    if (pending != null) await pending.future;
    final error = failWith;
    if (error != null) throw error;
    return {
      'items': [
        for (final id in snapshot)
          {'id': id, 'name': id, 'role': 'owner', 'lifecycle_status': 'expecting'},
      ],
      'has_more': false,
    };
  }
}

void main() {
  late _BabiesApi api;
  late DateTime now;
  var uid = 'user-1';
  late BabyListCache cache;

  setUp(() {
    api = _BabiesApi();
    now = DateTime(2026, 10, 18, 9);
    uid = 'user-1';
    cache = BabyListCache(
      api,
      currentUserId: () => uid,
      clock: () => now,
    );
  });

  test('concurrent reads share one request', () async {
    api.gate = Completer<void>();
    final reads = [cache.read(), cache.read(), cache.read()];
    api.gate!.complete();
    final results = await Future.wait(reads);
    expect(api.calls, 1);
    expect(results.every((r) => identical(r, results.first)), isTrue);
  });

  test('a fresh list is served from memory, an old one is refetched', () async {
    await cache.read();
    now = now.add(const Duration(seconds: 90));
    await cache.read();
    expect(api.calls, 1);
    now = now.add(BabyListCache.defaultFreshFor);
    await cache.read();
    expect(api.calls, 2);
  });

  test('markStale refetches and keeps the list as the offline fallback', () async {
    final online = await cache.read();
    cache.markStale();
    api.failWith = const SocketException('offline');
    final offline = await cache.read();
    expect(api.calls, 2);
    expect(offline, same(online));
  });

  test('a 4xx is never answered from the cached list', () async {
    await cache.read();
    cache.markStale();
    api.failWith = ApiException('forbidden', statusCode: 403);
    await expectLater(cache.read(), throwsA(isA<ApiException>()));
  });

  test('invalidate drops the list and ignores a response from before it', () async {
    await cache.read();
    cache.markStale();
    api.gate = Completer<void>();
    api.ids = ['baby-a', 'baby-b'];
    final before = cache.read();
    cache.invalidate();
    api.ids = ['baby-a'];
    api.gate!.complete();
    expect((await before).map((b) => b.id), ['baby-a', 'baby-b']);
    api.gate = null;
    final after = await cache.read();
    expect(after.map((b) => b.id), ['baby-a']);
    expect(api.calls, 3);
  });

  test('after invalidate there is no stale fallback when offline', () async {
    await cache.read();
    cache.invalidate();
    api.failWith = const SocketException('offline');
    await expectLater(cache.read(), throwsA(isA<SocketException>()));
  });

  test('another account never sees the cached list', () async {
    await cache.read();
    uid = 'user-2';
    api.failWith = const SocketException('offline');
    await expectLater(cache.read(), throwsA(isA<SocketException>()));
    expect(api.calls, 2);
  });
}
