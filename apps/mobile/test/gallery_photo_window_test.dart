import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/gallery/data/gallery_repository.dart';
import 'package:lanonna/features/gallery/presentation/photo_detail_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Photo list and detail endpoints over [photoIds], recording each request.
class _PhotosApi extends ApiClient {
  _PhotosApi(this.photoIds) : super(idTokenProvider: () async => 't');

  List<String> photoIds;
  final requests = <String>[];

  List<String> get listRequests =>
      requests.where((r) => r.contains('/photos?')).toList();
  List<String> get detailRequests =>
      requests.where((r) => !r.contains('/photos?')).toList();

  Map<String, dynamic> _photo(String id) => {
    'id': id,
    'status': 'ready',
    'created_at': '2026-10-01T12:00:00Z',
    'uploader_display_name': 'Alex',
  };

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    requests.add(path);
    final uri = Uri.parse(path);
    if (uri.path.endsWith('/photos')) {
      final limit = int.parse(uri.queryParameters['limit']!);
      final offset = int.parse(uri.queryParameters['offset']!);
      final page = photoIds.skip(offset).take(limit).toList();
      return {
        'items': [for (final id in page) _photo(id)],
        'has_more': offset + page.length < photoIds.length,
      };
    }
    return {..._photo(uri.pathSegments.last), 'comments': [], 'tagged_babies': []};
  }

  @override
  Future<void> deleteJson(String path, {Map<String, dynamic>? body}) async {
    requests.add('DELETE $path');
  }
}

class _Home extends HomeRepository {
  _Home() : super(ApiClient(idTokenProvider: () async => 't'));

  static const baby = BabySummary(
    id: 'baby-1',
    name: 'Parker',
    lifecycle: BabyLifecycle.born,
    role: 'follower',
  );

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async =>
      baby;

  @override
  Future<List<BabySummary>> listBabies() async => const [baby];
}

void main() {
  group('GalleryRepository photo window', () {
    test('records the grid pages as one window', () async {
      final api = _PhotosApi([for (var i = 0; i < 60; i++) 'p$i']);
      final repo = GalleryRepository(api);
      await repo.listPhotosPage('baby-1');
      expect(repo.photoWindow('baby-1', 'default')!.ids.length, 50);
      expect(repo.photoWindow('baby-1', 'default')!.hasMore, isTrue);

      await repo.extendPhotoWindow('baby-1', 'default');
      final window = repo.photoWindow('baby-1', 'default')!;
      expect(window.ids.length, 60);
      expect(window.hasMore, isFalse);
      expect(api.listRequests.last, contains('offset=50'));
      expect(repo.photoWindow('baby-1', 'newest'), isNull);
    });

    test('a grid refresh of the first page keeps the loaded tail', () async {
      final api = _PhotosApi([for (var i = 0; i < 60; i++) 'p$i']);
      final repo = GalleryRepository(api);
      await repo.listPhotosPage('baby-1');
      await repo.extendPhotoWindow('baby-1', 'default');
      await repo.listPhotosPage('baby-1');
      expect(repo.photoWindow('baby-1', 'default')!.ids.length, 60);

      api.photoIds = ['new', ...api.photoIds];
      await repo.listPhotosPage('baby-1');
      final window = repo.photoWindow('baby-1', 'default')!;
      expect(window.ids.first, 'new');
      expect(window.ids.length, 50, reason: 'a changed list restarts');
    });

    test('concurrent extends share one request', () async {
      final api = _PhotosApi(['a', 'b']);
      final repo = GalleryRepository(api);
      await Future.wait([
        repo.extendPhotoWindow('baby-1', 'default'),
        repo.extendPhotoWindow('baby-1', 'default'),
      ]);
      expect(api.listRequests, hasLength(1));
    });

    test('prefetched details are reused and shared', () async {
      var now = DateTime(2026, 10, 18, 9);
      final api = _PhotosApi(['a']);
      final repo = GalleryRepository(api, clock: () => now);
      await Future.wait([
        repo.prefetchPhoto('baby-1', 'a'),
        repo.prefetchPhoto('baby-1', 'a'),
      ]);
      expect(api.detailRequests, hasLength(1));
      expect(repo.cachedPhoto('baby-1', 'a')?.id, 'a');

      now = now.add(GalleryRepository.detailFreshFor);
      expect(repo.cachedPhoto('baby-1', 'a'), isNull);
    });

    test('deleting a photo drops it from the window and its detail', () async {
      final api = _PhotosApi(['a', 'b', 'c']);
      final repo = GalleryRepository(api);
      await repo.listPhotosPage('baby-1');
      await repo.prefetchPhoto('baby-1', 'b');
      await repo.deletePhoto('baby-1', 'b');
      expect(repo.photoWindow('baby-1', 'default')!.ids, ['a', 'c']);
      expect(repo.cachedPhoto('baby-1', 'b'), isNull);
    });

    test('sign-out clears windows and details', () async {
      final api = _PhotosApi(['a', 'b']);
      final repo = GalleryRepository(api);
      await repo.listPhotosPage('baby-1');
      await repo.prefetchPhoto('baby-1', 'a');
      repo.clearCachedPhotos();
      expect(repo.photoWindow('baby-1', 'default'), isNull);
      expect(repo.cachedPhoto('baby-1', 'a'), isNull);
    });
  });

  testWidgets(
    'photo detail reuses the gallery window and prefetches neighbours',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = _PhotosApi(['p1', 'p2', 'p3', 'p4']);
      final gallery = GalleryRepository(api);
      await gallery.listPhotosPage('baby-1');
      api.requests.clear();
      final photoId = ValueNotifier('p2');

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
            home: ValueListenableBuilder<String>(
              valueListenable: photoId,
              builder: (_, id, _) => PhotoDetailScreen(photoId: id),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(api.listRequests, isEmpty, reason: 'no re-paging from offset 0');
      expect(
        api.detailRequests.map((r) => r.split('/').last).toSet(),
        {'p1', 'p2', 'p3'},
      );

      // Next: the neighbour is already loaded.
      photoId.value = 'p3';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(api.listRequests, isEmpty);
      final details = api.detailRequests.map((r) => r.split('/').last).toList();
      expect(details.where((id) => id == 'p3'), hasLength(1));
      expect(details, contains('p4'), reason: 'the next neighbour is prefetched');
    },
  );
}
