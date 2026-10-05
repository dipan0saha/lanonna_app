import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/gallery_social_glyphs.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';
import 'package:lanonna/features/gallery/presentation/widgets/gallery_photo_grid.dart';

void main() {
  testWidgets('GalleryPhotoGrid shows comment and squish badges', (tester) async {
    final photos = [
      PhotoSummary(
        id: 'p1',
        status: 'ready',
        createdAt: DateTime(2026, 10, 1),
        squishCount: 3,
        commentCount: 2,
        uploaderDisplayName: 'Sarah',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GalleryPhotoGrid(
            photos: photos,
            onPhotoTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(GalleryCommentGlyph), findsOneWidget);
    expect(find.byType(GallerySquishGlyph), findsOneWidget);
  });

  testWidgets('GalleryPhotoGrid hides badges when counts are zero', (tester) async {
    final photos = [
      PhotoSummary(
        id: 'p2',
        status: 'ready',
        createdAt: DateTime(2026, 10, 1),
        squishCount: 0,
        commentCount: 0,
        uploaderDisplayName: 'Sarah',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GalleryPhotoGrid(
            photos: photos,
            onPhotoTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(GalleryCommentGlyph), findsNothing);
    expect(find.byType(GallerySquishGlyph), findsNothing);
  });
}
