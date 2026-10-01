import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/gallery/presentation/widgets/gallery_empty_state.dart';

void main() {
  testWidgets('Gallery empty state shows add button for owner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GalleryEmptyState(isOwner: true, onAddPhoto: () {}),
        ),
      ),
    );
    expect(find.text('No photos yet'), findsOneWidget);
    expect(find.text('+ Add Photo'), findsOneWidget);
  });
}
