import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';
import 'package:lanonna/features/gallery/presentation/widgets/gallery_photo_grid.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  testWidgets('the gallery grid builds only the tiles on screen', (
    tester,
  ) async {
    final photos = [
      for (var i = 0; i < 300; i++)
        PhotoSummary(
          id: 'p$i',
          status: 'ready',
          createdAt: DateTime(2026, 10, 1),
          squishCount: 0,
          commentCount: 0,
          uploaderDisplayName: 'Sarah',
        ),
    ];
    var tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              GalleryPhotoGrid(
                photos: photos,
                onPhotoTap: (p) => tapped.add(p.id),
              ),
            ],
          ),
        ),
      ),
    );
    final tiles = find.descendant(
      of: find.byType(GalleryPhotoGrid),
      matching: find.byType(GestureDetector),
    );
    final built = tiles.evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(60), reason: 'built $built of 300 tiles');

    // The last tile is still reachable by scrolling.
    await tester.scrollUntilVisible(
      find.bySemanticsIdentifier('gallery_photo_p299'),
      2000,
    );
    await tester.tap(find.bySemanticsIdentifier('gallery_photo_p299'));
    expect(tapped, ['p299']);
  });
}
