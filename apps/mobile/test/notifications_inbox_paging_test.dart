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

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
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
    return {'status': 'ok'};
  }
}

void main() {
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
