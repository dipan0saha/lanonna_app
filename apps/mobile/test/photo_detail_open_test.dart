import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/features/gallery/data/gallery_repository.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';
import 'package:lanonna/features/gallery/presentation/photo_detail_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Home extends HomeRepository {
  _Home() : super(ApiClient(idTokenProvider: () async => 't'));

  static const baby = BabySummary(
    id: 'baby-1',
    name: 'Parker',
    lifecycle: BabyLifecycle.born,
    role: 'owner',
  );

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async =>
      baby;

  @override
  Future<List<BabySummary>> listBabies() async => const [baby];
}

class _Gallery extends GalleryRepository {
  _Gallery() : super(ApiClient(idTokenProvider: () async => 't'));

  var listPhotosAllPagesCalls = 0;
  var fetchPhotoCalls = 0;

  @override
  Future<List<PhotoSummary>> listPhotos(
    String babyId, {
    String sort = 'default',
  }) async {
    listPhotosAllPagesCalls++;
    return const [];
  }

  @override
  Future<PhotoListPage> listPhotosPage(
    String babyId, {
    String sort = 'default',
    int limit = 50,
    int offset = 0,
  }) async {
    return PhotoListPage(items: const [], hasMore: false);
  }

  @override
  Future<PhotoDetail> fetchPhoto(String babyId, String photoId) async {
    fetchPhotoCalls++;
    return PhotoDetail(
      id: photoId,
      status: 'ready',
      caption: 'Hi',
      createdAt: DateTime.utc(2026, 10, 1),
      uploaderDisplayName: 'Alex',
      squishCount: 0,
      viewerHasSquished: false,
      comments: const [],
      taggedBabies: const [],
    );
  }
}

void main() {
  testWidgets('photo detail initial open uses fetchPhoto not listPhotos', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final gallery = _Gallery();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: _Home()),
          ChangeNotifierProvider<SelectedBabyStore>.value(
            value: SelectedBabyStore(await SharedPreferences.getInstance()),
          ),
          ChangeNotifierProvider<GalleryRepository>.value(value: gallery),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PhotoDetailScreen(photoId: 'photo-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(gallery.fetchPhotoCalls, 1);
    expect(gallery.listPhotosAllPagesCalls, 0);
    expect(find.byTooltip('Edit caption'), findsOneWidget);
  });

  testWidgets('photo detail load failure shows retry not photo not found', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final gallery = _FailingGallery();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: _Home()),
          ChangeNotifierProvider<SelectedBabyStore>.value(
            value: SelectedBabyStore(await SharedPreferences.getInstance()),
          ),
          ChangeNotifierProvider<GalleryRepository>.value(value: gallery),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PhotoDetailScreen(photoId: 'photo-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Photo not found'), findsNothing);
    expect(find.byKey(const Key('load_error_retry')), findsOneWidget);
  });
}

class _FailingGallery extends _Gallery {
  @override
  Future<PhotoDetail> fetchPhoto(String babyId, String photoId) async {
    throw ApiException('unavailable', statusCode: 503);
  }
}
