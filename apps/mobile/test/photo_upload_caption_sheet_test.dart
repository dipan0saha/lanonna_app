import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/gallery/presentation/upload/photo_upload_caption_sheet.dart';

final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late File imageFile;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('caption_sheet_test');
    imageFile = File('${dir.path}/thumb.png');
    await imageFile.writeAsBytes(_tinyPng);
  });

  testWidgets('skip returns null', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPhotoUploadCaptionSheet(
                  context,
                  imageFile: imageFile,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('post returns trimmed caption', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPhotoUploadCaptionSheet(
                  context,
                  imageFile: imageFile,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Hello family  ');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(result, 'Hello family');
  });
}
