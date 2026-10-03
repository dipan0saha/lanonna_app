import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/media/cached_signed_image.dart';

void main() {
  testWidgets('CachedSignedImage builds empty when url is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedSignedImage(imageUrl: null),
      ),
    );
    expect(find.byType(CachedSignedImage), findsOneWidget);
  });
}
