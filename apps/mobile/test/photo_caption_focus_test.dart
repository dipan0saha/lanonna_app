import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
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
    lifecycleStatus: 'born',
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

  var savedCaption = 'Hello';

  PhotoDetail get detail => PhotoDetail(
    id: 'photo-1',
    status: 'ready',
    caption: savedCaption,
    createdAt: DateTime.utc(2026, 10, 1),
    uploaderDisplayName: 'Alex',
    squishCount: 0,
    viewerHasSquished: false,
    comments: [
      PhotoComment(
        id: 'c1',
        body: 'So sweet',
        authorDisplayName: 'Alex',
        createdAt: DateTime.utc(2026, 10, 1),
        isMine: true,
        canEdit: true,
        canDelete: true,
      ),
    ],
    taggedBabies: const [],
  );

  @override
  Future<List<PhotoSummary>> listPhotos(
    String babyId, {
    String sort = 'default',
  }) async {
    return [
      PhotoSummary(
        id: 'photo-1',
        status: 'ready',
        caption: savedCaption,
        createdAt: DateTime.utc(2026, 10, 1),
        squishCount: 0,
        commentCount: 1,
        uploaderDisplayName: 'Alex',
      ),
    ];
  }

  @override
  Future<PhotoDetail> fetchPhoto(String babyId, String photoId) async => detail;

  @override
  Future<void> updateCaption(
    String babyId,
    String photoId,
    String? caption,
  ) async {
    savedCaption = caption ?? '';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('caption edit focuses the field and dismisses it on save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gallery = _Gallery();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: _Home()),
          ChangeNotifierProvider<SelectedBabyStore>.value(
            value: SelectedBabyStore(prefs),
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

    expect(find.byTooltip('Edit caption'), findsOneWidget);
    expect(find.byTooltip('Edit comment'), findsOneWidget);
    expect(find.byTooltip('Delete comment'), findsOneWidget);
    expect(find.byTooltip('Delete photo'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit caption'));
    await tester.pump();
    await tester.pump();

    final editing = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.focusNode?.hasFocus == true);
    expect(editing, isNotEmpty);

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Edit caption'), findsOneWidget);
    final stillFocused = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.focusNode?.hasFocus == true);
    expect(stillFocused, isEmpty);
    expect(gallery.savedCaption, 'Hello');
  });
}
