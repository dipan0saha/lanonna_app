import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/announcement/data/announcement_repository.dart';
import 'package:lanonna/features/announcement/presentation/announcement_card_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _NullAnnouncementRepository extends AnnouncementRepository {
  _NullAnnouncementRepository()
    : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<AnnouncementDetail?> fetch(String babyId) async => null;
}

class _RoleHomeRepository extends HomeRepository {
  _RoleHomeRepository(this.role)
    : super(ApiClient(idTokenProvider: () async => 't'));

  final String role;

  @override
  Future<BabySummary?> babyById(String babyId) async {
    return BabySummary(
      id: babyId,
      name: 'Luna',
      lifecycle: BabyLifecycle.born,
      role: role,
    );
  }
}

void main() {
  testWidgets('follower with no announcement sees empty state, not create form', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/baby/:babyId/announcement',
          builder: (context, state) => AnnouncementCardScreen(
            babyId: state.pathParameters['babyId']!,
          ),
        ),
        GoRoute(
          path: '/baby/:babyId/announcement/create',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('CREATE_FORM_STUB')),
          ),
        ),
      ],
      initialLocation: '/baby/baby-1/announcement',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(
            value: _RoleHomeRepository('follower'),
          ),
          Provider<AnnouncementRepository>.value(
            value: _NullAnnouncementRepository(),
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
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('No announcement yet').evaluate().isNotEmpty) break;
    }

    expect(find.text('No announcement yet'), findsOneWidget);
    expect(find.text('CREATE_FORM_STUB'), findsNothing);
    expect(find.text('Announce Arrival'), findsNothing);
  });

  testWidgets('owner with no announcement is routed to create', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/baby/:babyId/announcement',
          builder: (context, state) => AnnouncementCardScreen(
            babyId: state.pathParameters['babyId']!,
          ),
        ),
        GoRoute(
          path: '/baby/:babyId/announcement/create',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('CREATE_FORM_STUB')),
          ),
        ),
      ],
      initialLocation: '/baby/baby-1/announcement',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: _RoleHomeRepository('owner')),
          Provider<AnnouncementRepository>.value(
            value: _NullAnnouncementRepository(),
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

    expect(find.text('CREATE_FORM_STUB'), findsOneWidget);
  });
}
