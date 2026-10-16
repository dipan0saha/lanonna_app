import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/gallery/data/gallery_repository.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';
import 'package:lanonna/features/gallery/presentation/gallery_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_gallery_repository.dart';
import 'support/fake_home_repository.dart';
import 'support/fake_notifications_repository.dart';

/// Gallery also loads the recent-activity strip; stub it empty.
class _GalleryHomeRepository extends FakeHomeRepository {
  _GalleryHomeRepository(super.baby);

  @override
  Future<ActivityPage> fetchActivityPage(
    String babyId, {
    int limit = 20,
    int offset = 0,
    String? scope,
  }) async => ActivityPage(items: const [], hasMore: false);
}

Future<void> _pumpGallery(
  WidgetTester tester, {
  required FakeGalleryRepository galleryRepo,
  required HomeRefreshSignal homeRefresh,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final store = SelectedBabyStore(await SharedPreferences.getInstance());
  final baby = BabySummary(
    id: 'baby-1',
    name: 'Test Baby',
    role: 'owner',
    lifecycleStatus: 'expecting',
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
        ChangeNotifierProvider<GalleryRepository>.value(value: galleryRepo),
        Provider<HomeRefreshSignal>.value(value: homeRefresh),
        ChangeNotifierProvider<ConnectivityService>(
          create: (_) => ConnectivityService.forTesting(),
        ),
        Provider<HomeRepository>(create: (_) => _GalleryHomeRepository(baby)),
        ...shellTopBarTestProviders(),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GalleryScreen(),
      ),
    ),
  );
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (find.text('No photos yet').evaluate().isNotEmpty ||
        find.text('ALL PHOTOS').evaluate().isNotEmpty) {
      break;
    }
  }
}

void main() {
  testWidgets('GalleryRepository notifyListeners reloads photo grid', (
    tester,
  ) async {
    final galleryRepo = FakeGalleryRepository();
    final homeRefresh = HomeRefreshSignal();
    await _pumpGallery(
      tester,
      galleryRepo: galleryRepo,
      homeRefresh: homeRefresh,
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No photos yet'), findsOneWidget);
    final callsAfterLoad = galleryRepo.listCalls;

    galleryRepo.photos = [
      PhotoSummary(
        id: 'photo-1',
        status: 'ready',
        caption: 'Refresh test caption',
        createdAt: DateTime.utc(2026, 1, 1),
        thumbUrl: 'https://example.com/thumb.webp',
        squishCount: 0,
        commentCount: 0,
        uploaderDisplayName: 'Owner',
      ),
    ];
    galleryRepo.notifyListeners();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('ALL PHOTOS').evaluate().isNotEmpty) break;
    }

    expect(find.text('ALL PHOTOS'), findsOneWidget);
    expect(find.byTooltip('Add photo'), findsOneWidget);
    expect(find.bySemanticsLabel('Refresh test caption'), findsOneWidget);
    expect(galleryRepo.listCalls, greaterThan(callsAfterLoad));
  });

  testWidgets('home tab refresh does not reload gallery list', (tester) async {
    final galleryRepo = FakeGalleryRepository();
    final homeRefresh = HomeRefreshSignal();
    await _pumpGallery(
      tester,
      galleryRepo: galleryRepo,
      homeRefresh: homeRefresh,
    );

    expect(find.text('No photos yet'), findsOneWidget);
    final callsAfterLoad = galleryRepo.listCalls;

    galleryRepo.photos = [
      PhotoSummary(
        id: 'photo-2',
        status: 'ready',
        createdAt: DateTime.utc(2026, 2, 1),
        thumbUrl: 'https://example.com/thumb2.webp',
        squishCount: 1,
        commentCount: 0,
        uploaderDisplayName: 'Owner',
      ),
    ];
    homeRefresh.notifyHomeShouldRefresh();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No photos yet'), findsOneWidget);
    expect(galleryRepo.listCalls, callsAfterLoad);
  });

  testWidgets('baby context refresh reloads gallery list', (tester) async {
    final galleryRepo = FakeGalleryRepository();
    final homeRefresh = HomeRefreshSignal();
    await _pumpGallery(
      tester,
      galleryRepo: galleryRepo,
      homeRefresh: homeRefresh,
    );

    expect(find.text('No photos yet'), findsOneWidget);
    final callsAfterLoad = galleryRepo.listCalls;

    galleryRepo.photos = [
      PhotoSummary(
        id: 'photo-2',
        status: 'ready',
        createdAt: DateTime.utc(2026, 2, 1),
        thumbUrl: 'https://example.com/thumb2.webp',
        squishCount: 1,
        commentCount: 0,
        uploaderDisplayName: 'Owner',
      ),
    ];
    homeRefresh.notifyBabyContextChanged();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('ALL PHOTOS').evaluate().isNotEmpty) break;
    }

    expect(find.text('ALL PHOTOS'), findsOneWidget);
    expect(galleryRepo.listCalls, greaterThan(callsAfterLoad));
  });
}
