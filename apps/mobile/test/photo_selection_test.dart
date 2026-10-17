import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:lanonna/core/media/photo_selection.dart';
import 'package:lanonna/core/widgets/photo_selection_preview.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  group('PhotoSelection', () {
    test('fromStored treats blank as none', () {
      expect(PhotoSelection.fromStored(null).hasPhoto, isFalse);
      expect(PhotoSelection.fromStored('  ').hasPhoto, isFalse);
      final stored = PhotoSelection.fromStored('p1', previewUrl: 'https://x');
      expect(stored.remoteRef, 'p1');
      expect(stored.needsUpload, isFalse);
    });

    test('a picked file needs upload until marked uploaded', () {
      final local = PhotoSelection.local(XFile('/tmp/a.jpg'));
      expect(local.hasPhoto, isTrue);
      expect(local.needsUpload, isTrue);
      final uploaded = local.uploaded('p2');
      expect(uploaded.needsUpload, isFalse);
      expect(uploaded.remoteRef, 'p2');
      expect(uploaded.localFile?.path, '/tmp/a.jpg');
    });

    test('fromPicked maps a cancelled pick to none', () {
      expect(PhotoSelection.fromPicked(null), const PhotoSelection.none());
    });
  });

  group('PhotoSelectionPreview', () {
    Future<void> pump(
      WidgetTester tester,
      PhotoSelection selection, {
      bool busy = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PhotoSelectionPreview(
              selection: selection,
              width: 100,
              height: 70,
              busy: busy,
            ),
          ),
        ),
      );
    }

    testWidgets('shows the placeholder with no photo', (tester) async {
      await pump(tester, const PhotoSelection.none());
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows a picked file before upload', (tester) async {
      await pump(tester, PhotoSelection.local(XFile('/tmp/a.jpg')));
      expect(find.byType(LocalPhotoImage), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
    });

    testWidgets('busy shows a labelled upload spinner', (tester) async {
      await pump(tester, PhotoSelection.local(XFile('/tmp/a.jpg')), busy: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Uploading photo…'), findsOneWidget);
    });
  });
}
