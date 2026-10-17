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

PhotoSummary _photo(String id) => PhotoSummary(
  id: id,
  status: 'ready',
  caption: 'Photo $id',
  createdAt: DateTime.utc(2026, 3, 1),
  thumbUrl: 'https://example.com/$id.webp',
  squishCount: 0,
  commentCount: 0,
  uploaderDisplayName: 'Owner',
);

void main() {
  testWidgets('gallery incremental refresh adds fifth photo tile', (
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
    galleryRepo.photos = ['1', '2', '3', '4'].map(_photo).toList();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ChangeNotifierProvider<GalleryRepository>.value(value: galleryRepo),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
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
      if (find.text('ALL PHOTOS').evaluate().isNotEmpty) break;
    }

    expect(find.bySemanticsLabel('Photo 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Photo 4'), findsOneWidget);
    expect(find.bySemanticsLabel('Photo 5'), findsNothing);

    galleryRepo.photos = ['5', '1', '2', '3', '4'].map(_photo).toList();
    galleryRepo.notifyListeners();

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.bySemanticsLabel('Photo 5').evaluate().isNotEmpty) break;
    }

    expect(find.bySemanticsLabel('Photo 5'), findsOneWidget);
    expect(find.bySemanticsLabel('Photo 4'), findsOneWidget);
  });
}
