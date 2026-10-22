import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/account/presentation/followers_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository({this.invites = const []})
    : super(ApiClient(idTokenProvider: () async => null));

  final List<InvitationRow> invites;
  int removeCalls = 0;
  int revokeCalls = 0;

  @override
  Future<List<MemberRow>> listMembers(String babyId) async {
    return [
      MemberRow(
        firebaseUid: 'uid-follower',
        displayName: 'Alex',
        role: 'follower',
        canRemove: true,
      ),
    ];
  }

  @override
  Future<List<InvitationRow>> listInvitations(String babyId) async =>
      invites;

  @override
  Future<void> removeMember(String babyId, String firebaseUid) async {
    removeCalls++;
  }

  @override
  Future<void> revokeInvitation(String babyId, String invitationId) async {
    revokeCalls++;
  }
}

class _FakeHomeRepository extends HomeRepository {
  _FakeHomeRepository() : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<BabySummary?> babyById(String babyId) async => null;
}

Future<void> _pumpFollowers(
  WidgetTester tester,
  _FakeAccountRepository repo,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiProvider(
        providers: [
          Provider<AccountRepository>.value(value: repo),
          Provider<HomeRepository>.value(value: _FakeHomeRepository()),
        ],
        child: const FollowersScreen(babyId: 'baby-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('remove follower shows Remove and confirms with Remove', (
    tester,
  ) async {
    final repo = _FakeAccountRepository();
    await _pumpFollowers(tester, repo);

    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Revoke'), findsNothing);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from family?'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(repo.removeCalls, 1);
  });

  testWidgets('cancel remove follower confirm does not remove', (tester) async {
    final repo = _FakeAccountRepository();
    await _pumpFollowers(tester, repo);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(repo.removeCalls, 0);
  });

  testWidgets('revoke invite confirms with Revoke', (tester) async {
    final repo = _FakeAccountRepository(
      invites: [
        InvitationRow(
          id: 'inv-1',
          email: 'friend@example.com',
          status: InvitationStatus.pending,
        ),
      ],
    );
    await _pumpFollowers(tester, repo);

    expect(find.text('Revoke'), findsOneWidget);
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke invitation?'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Revoke'));
    await tester.pumpAndSettle();
    expect(repo.revokeCalls, 1);
  });

  testWidgets('cancel revoke invite confirm does not revoke', (tester) async {
    final repo = _FakeAccountRepository(
      invites: [
        InvitationRow(
          id: 'inv-1',
          email: 'friend@example.com',
          status: InvitationStatus.pending,
        ),
      ],
    );
    await _pumpFollowers(tester, repo);

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(repo.revokeCalls, 0);
  });
}
