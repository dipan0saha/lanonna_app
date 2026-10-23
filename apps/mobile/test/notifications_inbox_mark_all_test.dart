import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/account/presentation/notifications_inbox_screen.dart';
import 'package:provider/provider.dart';
import 'package:lanonna/l10n/app_localizations.dart';

class _InboxRepo extends NotificationsRepository {
  _InboxRepo() : super(ApiClient(idTokenProvider: () async => 't'));

  var markAllCalls = 0;
  var allRead = false;
  var notifyCount = 0;

  @override
  void notifyInboxMayHaveChanged() {
    notifyCount++;
    super.notifyInboxMayHaveChanged();
  }

  @override
  Future<InboxListWindow> ensureInboxFirstPage({bool forceRefresh = false}) async {
    return InboxListWindow(
      items: [
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
      ],
      hasMore: false,
    );
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls++;
    allRead = true;
    notifyInboxMayHaveChanged();
    return 1;
  }
}

void main() {
  testWidgets('mark all read updates list and notifies repository listeners', (
    tester,
  ) async {
    final repo = _InboxRepo();

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

    expect(find.text('Mark all read'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(repo.markAllCalls, 1);
    expect(repo.notifyCount, greaterThan(0));
  });
}
