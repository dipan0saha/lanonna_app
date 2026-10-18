import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';

class _Api extends ApiClient {
  _Api() : super(idTokenProvider: () async => 't');

  final requests = <String>[];
  Completer<void>? gate;
  var unread = 3;
  var displayName = 'Alex';

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    requests.add(path);
    final pending = gate;
    if (pending != null) await pending.future;
    if (path == '/v1/me/notifications/unread-count') return {'count': unread};
    if (path == '/v1/me/account') {
      return {
        'profile': {'display_name': displayName},
        'babies': [],
      };
    }
    throw UnimplementedError(path);
  }
}

void main() {
  group('unread count', () {
    test('every top bar refreshing at once makes one request', () async {
      final api = _Api();
      final repo = NotificationsRepository(api);
      api.gate = Completer<void>();
      final refreshes = [for (var i = 0; i < 5; i++) repo.refreshUnreadCount()];
      api.gate!.complete();
      await Future.wait(refreshes);
      expect(api.requests, hasLength(1));
      expect(repo.unread.count, 3);
    });

    test('maxAge keeps a recent count', () async {
      var now = DateTime(2026, 10, 18, 9);
      final api = _Api();
      final repo = NotificationsRepository(api, clock: () => now);
      await repo.refreshUnreadCount();
      await repo.refreshUnreadCount(maxAge: const Duration(seconds: 30));
      expect(api.requests, hasLength(1));
      now = now.add(const Duration(seconds: 30));
      await repo.refreshUnreadCount(maxAge: const Duration(seconds: 30));
      expect(api.requests, hasLength(2));
    });

    test('sign-out resets the count and ignores an in-flight answer', () async {
      final api = _Api();
      final repo = NotificationsRepository(api);
      await repo.refreshUnreadCount();
      api.gate = Completer<void>();
      api.unread = 9;
      final pending = repo.refreshUnreadCount();
      repo.clearUnreadCount();
      api.gate!.complete();
      await pending;
      expect(repo.unread.count, 0);
    });
  });

  group('account', () {
    test('launch callers share one account request', () async {
      final api = _Api();
      final repo = AccountRepository(api);
      api.gate = Completer<void>();
      final loads = [repo.ensureAccountLoaded(), repo.ensureAccountLoaded()];
      api.gate!.complete();
      await Future.wait(loads);
      await repo.ensureAccountLoaded();
      expect(api.requests, ['/v1/me/account']);
      expect(repo.cachedAccount?.displayName, 'Alex');
    });

    test('sign-out clears the account; a late answer is not cached', () async {
      final api = _Api();
      final repo = AccountRepository(api);
      api.gate = Completer<void>();
      final pending = repo.ensureAccountLoaded();
      repo.clearCachedAccount();
      api.gate!.complete();
      await pending;
      expect(repo.cachedAccount, isNull);

      api.gate = null;
      api.displayName = 'Sam';
      await repo.ensureAccountLoaded();
      expect(repo.cachedAccount?.displayName, 'Sam');
    });
  });
}
