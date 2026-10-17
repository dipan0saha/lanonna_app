import 'package:firebase_auth/firebase_auth.dart';
import 'package:lanonna/features/account/domain/notification_digest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/account/presentation/account_edit_screen.dart';
import 'package:lanonna/features/account/presentation/account_screen.dart';
import 'package:provider/provider.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _Auth extends AuthRepository {
  _Auth() : super(firebaseAuth: _FakeFirebaseAuth());

  @override
  User? get currentUser => null;
}

class _Accounts extends AccountRepository {
  _Accounts() : super(ApiClient(idTokenProvider: () async => 't'));

  String name = 'Fxtwo Coown';
  var updates = 0;

  AccountPayload _payload() {
    return AccountPayload(
      displayName: name,
      email: 'coown@test.com',
      babies: const [],
      engagement: const UserEngagementStats(
        photosSquished: 0,
        eventsAttended: 0,
        itemsBought: 0,
        comments: 0,
      ),
    );
  }

  @override
  Future<AccountPayload> fetchAccount() async {
    profileUpdates.account = _payload();
    return profileUpdates.account!;
  }

  @override
  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
    String? phone,
    String? birthDate,
    String? countryCode,
    String? postalCode,
    bool sendExplicitNulls = false,
  }) async {
    updates++;
    name = displayName;
    profileUpdates.publish(_payload());
  }
}

class _Notifications extends NotificationsRepository {
  _Notifications() : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    return NotificationPreferences(
      digest: NotificationDigest.weekly,
      pushEnabled: true,
      emailDigestEnabled: true,
      notifyGalleryEnabled: true,
      notifyCalendarEnabled: true,
      notifyRegistryEnabled: true,
      notifyCommentsEnabled: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty first name and invalid phone do not save', (tester) async {
    final accounts = _Accounts();
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const AccountScreen()),
        GoRoute(
          path: '/account/edit',
          builder: (_, _) => const AccountEditScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AccountRepository>.value(value: accounts),
          Provider<AuthRepository>.value(value: _Auth()),
          ChangeNotifierProvider<NotificationsRepository>.value(
            value: _Notifications(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fxtwo Coown'), findsOneWidget);
    expect(find.text('Weekly email summary'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(3), 'abc');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('First name is required'), findsOneWidget);
    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(accounts.updates, 0);
    expect(find.text('Save'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Nova');
    await tester.enterText(fields.at(3), '+1 (555) 010-1234');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(accounts.updates, 1);
    expect(find.text('Nova Coown'), findsOneWidget);
    expect(find.text('My Account'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });
}
