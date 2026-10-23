import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/account/presentation/notifications_inbox_screen.dart';
import 'package:provider/provider.dart';
import 'package:lanonna/l10n/app_localizations.dart';

class _InboxApi extends ApiClient {
  _InboxApi() : super(idTokenProvider: () async => 't');

  var listCalls = 0;
  var patchCalls = 0;
  var unreadCount = 2;

  /// Overrides the first page's rows (newest first) when set.
  List<Map<String, dynamic>>? firstPage;
  var firstPageHasMore = true;

  /// When set, PATCH waits on it; [failPatch] then makes it throw.
  Completer<void>? patchGate;
  var failPatch = false;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    if (path == '/v1/me/notifications/unread-count') {
      return {'count': unreadCount};
    }
    if (path.startsWith('/v1/me/notifications')) {
      listCalls++;
      if (path.contains('cursor=')) {
        return {
          'items': [
            {
              'id': 'n3',
              'title': 'Three',
              'body': '',
              'created_at': '2026-01-03T00:00:00Z',
            },
          ],
          'limit': 50,
          'has_more': false,
          'next_cursor': null,
        };
      }
      final override = firstPage;
      if (override != null) {
        return {
          'items': override,
          'limit': 50,
          'has_more': firstPageHasMore,
          'next_cursor': firstPageHasMore ? 'c1' : null,
        };
      }
      return {
        'items': [
          {
            'id': 'n1',
            'title': 'One',
            'body': '',
            'created_at': '2026-01-01T00:00:00Z',
          },
          {
            'id': 'n2',
            'title': 'Two',
            'body': '',
            'created_at': '2026-01-02T00:00:00Z',
          },
        ],
        'limit': 50,
        'has_more': true,
        'next_cursor': 'c1',
      };
    }
    throw UnimplementedError(path);
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    patchCalls++;
    final gate = patchGate;
    if (gate != null) await gate.future;
    if (failPatch) throw const SocketException('offline');
    return {'status': 'ok'};
  }
}

Map<String, dynamic> _row(String id, {String? readAt}) => {
  'id': id,
  'title': id,
  'body': '',
  'created_at': '2026-01-01T00:00:00Z',
  'read_at': readAt,
};

void main() {
  test('markRead updates row and badge before the request, rolls back on failure', () async {
    final api = _InboxApi();
    final repo = NotificationsRepository(api);
    await repo.refreshUnreadCount();
    await repo.ensureInboxFirstPage();
    expect(repo.unread.count, 2);

    final gate = Completer<void>();
    api
      ..patchGate = gate
      ..failPatch = true;
    final pending = repo.markRead('n1');
    expect(repo.unread.count, 1);
    expect(repo.peekInbox()!.items.first.readAt, isNotNull);

    gate.complete();
    await expectLater(pending, throwsA(isA<SocketException>()));
    expect(repo.unread.count, 2);
    expect(repo.peekInbox()!.items.first.readAt, isNull);
  });

  test('a page fetched while markRead is pending keeps the row read', () async {
    final api = _InboxApi();
    final repo = NotificationsRepository(api);
    await repo.ensureInboxFirstPage();
    final gate = Completer<void>();
    api.patchGate = gate;
    final pending = repo.markRead('n1');

    await repo.revalidateInbox();
    expect(repo.peekInbox()!.items.first.readAt, isNotNull);

    gate.complete();
    await pending;
    expect(repo.peekInbox()!.items.first.readAt, isNotNull);
  });

  test('revalidating keeps older pages already loaded', () async {
    final api = _InboxApi();
    final repo = NotificationsRepository(api);
    await repo.ensureInboxFirstPage();
    await repo.extendInbox();
    expect(repo.peekInbox()!.items.map((n) => n.id), ['n1', 'n2', 'n3']);

    // A new row arrives at the head; n2 is still the first page's tail.
    api.firstPage = [_row('n0'), _row('n1'), _row('n2')];
    await repo.revalidateInbox();
    final window = repo.peekInbox()!;
    expect(window.items.map((n) => n.id), ['n0', 'n1', 'n2', 'n3']);
    expect(window.hasMore, isFalse);
  });

  test('sign-out drops the inbox and a page still in flight', () async {
    final api = _InboxApi();
    final repo = NotificationsRepository(api);
    await repo.ensureInboxFirstPage();
    final extending = repo.extendInbox();
    repo.clearUnreadCount();
    await extending;
    expect(repo.peekInbox(), isNull);
    expect(repo.isInboxFresh, isFalse);
  });

  test('extendInbox loads the next cursor page', () async {
    final api = _InboxApi();
    final repo = NotificationsRepository(api);
    await repo.ensureInboxFirstPage();
    expect(repo.peekInbox()!.items, hasLength(2));
    await repo.extendInbox();
    expect(repo.peekInbox()!.items.map((n) => n.id).toList(), ['n1', 'n2', 'n3']);
    expect(api.listCalls, 2);
  });

  testWidgets('mark read does not refetch the inbox list', (tester) async {
    final api = _InboxApi();
    final repo = NotificationsRepository(api);

    await tester.pumpWidget(
      ChangeNotifierProvider<NotificationsRepository>.value(
        value: repo,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationsInboxScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.listCalls, 1);
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();

    expect(api.patchCalls, 1);
    expect(api.listCalls, 1);
    expect(repo.peekInbox()!.items.first.readAt, isNotNull);
  });
}
