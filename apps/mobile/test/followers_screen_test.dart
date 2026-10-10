import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/account/presentation/followers_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository() : super(ApiClient(idTokenProvider: () async => null));

  int removeCalls = 0;

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
  Future<List<InvitationRow>> listInvitations(String babyId) async => [];

  @override
  Future<void> removeMember(String babyId, String firebaseUid) async {
    removeCalls++;
  }
}

void main() {
  testWidgets('remove button visible when can_remove', (tester) async {
    final repo = _FakeAccountRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Provider<AccountRepository>.value(
          value: repo,
          child: const FollowersScreen(babyId: 'baby-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_remove_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(repo.removeCalls, 1);
  });
}
