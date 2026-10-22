import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/presentation/widgets/home_owner_sections.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository({this.fail = false})
    : super(ApiClient(idTokenProvider: () async => null));

  final bool fail;
  int revokeCalls = 0;

  @override
  Future<void> revokeInvitation(String babyId, String invitationId) async {
    revokeCalls++;
    if (fail) throw Exception('network');
  }
}

Future<int Function()> _pump(
  WidgetTester tester,
  _FakeAccountRepository repo,
) async {
  var changed = 0;
  await tester.pumpWidget(
    Provider<AccountRepository>.value(
      value: repo,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeInviteStatusSection(
              babyId: 'baby-1',
              invites: const [
                HomeInviteStatusRow(
                  id: 'inv-1',
                  inviteeEmail: 'friend@example.com',
                  status: InvitationStatus.pending,
                  createdAt: '2026-01-01T00:00:00Z',
                ),
              ],
              onChanged: () => changed++,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return () => changed;
}

void main() {
  testWidgets('home invite revoke asks first; cancel does nothing', (
    tester,
  ) async {
    final repo = _FakeAccountRepository();
    final changed = await _pump(tester, repo);

    await tester.tap(find.byTooltip('Revoke invitation'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke invitation?'), findsOneWidget);
    expect(
      find.text(
        'friend@example.com will no longer be able to join with this invite.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(repo.revokeCalls, 0);
    expect(changed(), 0);
  });

  testWidgets('home invite revoke confirm revokes and refreshes', (
    tester,
  ) async {
    final repo = _FakeAccountRepository();
    final changed = await _pump(tester, repo);

    await tester.tap(find.byTooltip('Revoke invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Revoke'));
    await tester.pumpAndSettle();
    expect(repo.revokeCalls, 1);
    expect(changed(), 1);
  });

  testWidgets('home invite revoke failure shows an alert, no refresh', (
    tester,
  ) async {
    final repo = _FakeAccountRepository(fail: true);
    final changed = await _pump(tester, repo);

    await tester.tap(find.byTooltip('Revoke invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Revoke'));
    await tester.pumpAndSettle();
    expect(repo.revokeCalls, 1);
    expect(changed(), 0);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
