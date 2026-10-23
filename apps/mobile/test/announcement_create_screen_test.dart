import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/announcement/data/announcement_repository.dart';
import 'package:lanonna/features/announcement/presentation/announcement_create_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';

void main() {
  testWidgets('announcement create shows prototype fields', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const AnnouncementCreateScreen(babyId: 'baby-1'),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>(
            create: (_) => _OwnerHomeRepository(),
          ),
          Provider<AnnouncementRepository>(
            create: (_) => AnnouncementRepository(_FakeApi()),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('announcement_first_name')), findsOneWidget);
    expect(find.text('Announce Arrival'), findsOneWidget);
    expect(find.text('Boy'), findsOneWidget);
    expect(find.text('Girl'), findsOneWidget);
  });
}

class _FakeApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _OwnerHomeRepository extends HomeRepository {
  _OwnerHomeRepository() : super(_FakeApi());

  @override
  Future<BabySummary?> babyById(String babyId) async {
    return const BabySummary(
      id: 'baby-1',
      name: 'Luna',
      lifecycle: BabyLifecycle.born,
      role: 'owner',
    );
  }
}
