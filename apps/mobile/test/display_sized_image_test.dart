import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:lanonna/core/media/cached_signed_image.dart';
import 'package:lanonna/core/media/display_sized_image.dart';
import 'package:lanonna/core/widgets/account_tinted_avatar.dart';
import 'package:lanonna/core/widgets/photo_selection_preview.dart';
import 'package:octo_image/octo_image.dart';

const _signed =
    'https://storage.googleapis.com/lanonna-dev-display/display/p1.webp'
    '?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Signature=abc';

Widget _host(Widget child, {double dpr = 2}) => MediaQuery(
  data: MediaQueryData(devicePixelRatio: dpr),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

void main() {
  group('targetDecodeSize', () {
    ui.TargetImageSize t(int w, int h, Size box, BoxFit fit) =>
        targetDecodeSize(w, h, box: box, fit: fit);

    test('cover fills both sides of the slot, keeping the aspect ratio', () {
      // 2048x1536 photo in photo detail's 1080 px square.
      final s = t(2048, 1536, const Size(1080, 1080), BoxFit.cover);
      expect((s.width, s.height), (1440, 1080));
    });

    test('contain and scaleDown fit inside the slot', () {
      for (final fit in [BoxFit.contain, BoxFit.scaleDown]) {
        final s = t(2048, 1536, const Size(1080, 1080), fit);
        expect((s.width, s.height), (1080, 810));
      }
    });

    test('an unbounded side sizes by the other side', () {
      final s = t(2048, 1536, const Size(1080, double.infinity), BoxFit.cover);
      expect((s.width, s.height), (1080, 810));
    });

    test('never upscales: a small image decodes at its own size', () {
      // A 320x426 thumbnail in a 357 px tile.
      final s = t(320, 426, const Size(357, 357), BoxFit.cover);
      expect((s.width, s.height), (null, null));
    });
  });

  group('DisplaySizedImage', () {
    final inner = MemoryImage(Uint8List(1));

    test('forSlot leaves unconstrained slots and BoxFit.none alone', () {
      expect(
        DisplaySizedImage.forSlot(
          inner,
          logicalSize: Size.infinite,
          devicePixelRatio: 3,
          fit: BoxFit.cover,
        ),
        same(inner),
      );
      expect(
        DisplaySizedImage.forSlot(
          inner,
          logicalSize: const Size(10, 10),
          devicePixelRatio: 3,
          fit: BoxFit.none,
        ),
        same(inner),
      );
    });

    test('the slot is in whole physical pixels and part of the key', () {
      final a = DisplaySizedImage.forSlot(
        inner,
        logicalSize: const Size(100.2, 50),
        devicePixelRatio: 2,
        fit: BoxFit.cover,
      );
      expect((a as DisplaySizedImage).box, const Size(201, 100));
      expect(
        a,
        DisplaySizedImage(inner, box: const Size(201, 100), fit: BoxFit.cover),
      );
      expect(
        a,
        isNot(
          DisplaySizedImage(
            inner,
            box: const Size(300, 100),
            fit: BoxFit.cover,
          ),
        ),
      );
    });

    testWidgets('decodes at the slot size', (tester) async {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 400, height: 300)),
      );
      final provider = DisplaySizedImage(
        MemoryImage(png),
        box: const Size(100, 100),
        fit: BoxFit.cover,
      );
      final image = await tester.runAsync(() {
        final done = Completer<ui.Image>();
        provider
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener((info, _) => done.complete(info.image)),
            );
        return done.future;
      });
      expect((image!.width, image.height), (134, 100));
    });
  });

  testWidgets('CachedSignedImage decodes at its slot and keys by object path', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 100,
          height: 50,
          child: CachedSignedImage(imageUrl: _signed),
        ),
      ),
    );
    final octo = tester.widget<OctoImage>(find.byType(OctoImage));
    final sized = octo.image as DisplaySizedImage;
    expect(sized.box, const Size(200, 100));
    expect(sized.fit, BoxFit.cover);
    final net = sized.imageProvider as CachedNetworkImageProvider;
    expect(
      net.cacheKey,
      'storage.googleapis.com/lanonna-dev-display/display/p1.webp',
    );
  });

  testWidgets('the account avatar uses the shared cached image', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const AccountTintedAvatar(displayName: 'Ann', imageUrl: _signed)),
    );
    expect(find.byType(CachedSignedImage), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
      findsNothing,
    );
  });

  testWidgets('a picked photo decodes at its slot size', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox.square(
          dimension: 96,
          child: LocalPhotoImage(file: XFile('/tmp/picked.jpg')),
        ),
        dpr: 3,
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as DisplaySizedImage).box, const Size(288, 288));
  });
}
