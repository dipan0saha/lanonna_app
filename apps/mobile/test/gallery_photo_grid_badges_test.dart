import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
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
    expect(find.byIcon(Icons.back_hand_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
  });
}
