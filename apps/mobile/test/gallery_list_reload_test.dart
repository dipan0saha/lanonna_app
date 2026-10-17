import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
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

void main() {
  testWidgets('coalesced gallery refresh shows photo after second notify', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final baby = BabySummary(
      id: 'baby-1',
      name: 'Test Baby',
      role: 'owner',
      lifecycle: BabyLifecycle.expecting,
    );
    final galleryRepo = FakeGalleryRepository();
    final homeRefresh = HomeRefreshSignal();

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
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('No photos yet').evaluate().isNotEmpty) break;
    }

    galleryRepo.photos = [
      PhotoSummary(
        id: 'photo-1',
        status: 'ready',
        caption: 'Coalesced refresh',
        createdAt: DateTime.utc(2026, 3, 1),
        thumbUrl: 'https://example.com/thumb.webp',
        squishCount: 2,
        commentCount: 1,
        uploaderDisplayName: 'Owner',
      ),
    ];
    galleryRepo.notifyListeners();
    galleryRepo.notifyListeners();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('ALL PHOTOS').evaluate().isNotEmpty) break;
    }

    expect(find.text('ALL PHOTOS'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Coalesced refresh')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
