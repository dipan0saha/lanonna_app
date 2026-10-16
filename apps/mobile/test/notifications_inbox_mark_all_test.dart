import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/account/data/notifications_unread_signal.dart';
import 'package:lanonna/features/account/presentation/notifications_inbox_screen.dart';
import 'package:provider/provider.dart';

class _InboxRepo extends NotificationsRepository {
  _InboxRepo() : super(ApiClient(idTokenProvider: () async => 't'));

  var markAllCalls = 0;
  var allRead = false;

  @override
  Future<List<InboxNotification>> listInbox() async {
    return [
      InboxNotification(
        id: 'n1',
        title: 'New photo',
        body: 'Alex added a photo',
        readAt: allRead ? '2026-01-01T00:00:00Z' : null,
      ),
      InboxNotification(
        id: 'n2',
        title: 'Event reminder',
        body: 'Tomorrow',
        readAt: '2026-01-01T00:00:00Z',
      ),
    ];
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls++;
    allRead = true;
    return 1;
  }
}

void main() {
  testWidgets('mark all read updates list and notifies unread signal', (
    tester,
  ) async {
    final repo = _InboxRepo();
    final unreadSignal = NotificationsUnreadSignal();
    var unreadNotifications = 0;
    unreadSignal.addListener(() => unreadNotifications++);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<NotificationsRepository>.value(value: repo),
          ChangeNotifierProvider<NotificationsUnreadSignal>.value(
            value: unreadSignal,
          ),
        ],
        child: const MaterialApp(home: NotificationsInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mark all read'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(repo.markAllCalls, 1);
    expect(unreadNotifications, 1);
    expect(find.text('Mark all read'), findsNothing);
  });
}
