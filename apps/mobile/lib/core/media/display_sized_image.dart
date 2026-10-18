import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Decodes [imageProvider] at the size its slot shows it, not at the stored
/// size.
///
/// [box] is the slot in physical pixels (logical size × device pixel ratio);
/// an infinite side is unconstrained. At decode time the image's real size is
/// known, so [targetDecodeSize] picks the smallest size that still fills the
/// slot for [fit], keeps the aspect ratio and never upscales. On screen the
/// image looks the same; it just holds no more pixels than the slot can show.
///
/// Like [ResizeImage], but sized from the slot and the fit instead of fixed
/// numbers, which a `cover` slot needs because the image's aspect ratio is
/// only known once it is decoded.
@immutable
class DisplaySizedImage extends ImageProvider<DisplaySizedImageKey> {
  DisplaySizedImage(this.imageProvider, {required Size box, required this.fit})
    : box = Size(_px(box.width), _px(box.height));

  /// Wraps [provider] for a slot of [logicalSize] at [devicePixelRatio], or
  /// returns it as is when the slot is unconstrained or [fit] is
  /// [BoxFit.none] (the image is drawn at its own size).
  static ImageProvider<Object> forSlot(
    ImageProvider<Object> provider, {
    required Size logicalSize,
    required double devicePixelRatio,
    required BoxFit fit,
  }) {
    final unconstrained =
        !logicalSize.width.isFinite && !logicalSize.height.isFinite;
    if (unconstrained || fit == BoxFit.none) return provider;
    return DisplaySizedImage(
      provider,
      box: logicalSize * devicePixelRatio,
      fit: fit,
    );
  }

  final ImageProvider<Object> imageProvider;

  /// Slot size in whole physical pixels (rounded up); infinite = unconstrained.
  final Size box;
  final BoxFit fit;

  static double _px(double v) => v.isFinite ? v.ceilToDouble() : v;

  @override
  Future<DisplaySizedImageKey> obtainKey(ImageConfiguration configuration) {
    Completer<DisplaySizedImageKey>? completer;
    SynchronousFuture<DisplaySizedImageKey>? result;
    imageProvider.obtainKey(configuration).then((Object key) {
      final sized = DisplaySizedImageKey._(key, box, fit);
      if (completer == null) {
        result = SynchronousFuture<DisplaySizedImageKey>(sized);
      } else {
        completer.complete(sized);
      }
    });
    if (result != null) return result!;
    completer = Completer<DisplaySizedImageKey>();
    return completer.future;
  }

  @override
  ImageStreamCompleter loadImage(
    DisplaySizedImageKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> decodeAtSlotSize(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) {
      assert(
        getTargetSize == null,
        'DisplaySizedImage wraps providers that do not size their own decode',
      );
      return decode(
        buffer,
        getTargetSize: (int width, int height) =>
            targetDecodeSize(width, height, box: box, fit: fit),
      );
    }

    final completer = imageProvider.loadImage(
      key._providerKey,
      decodeAtSlotSize,
    );
    // The inner provider evicts its own key on failure; the cached entry is
    // this key, so evict it too and a later load (e.g. a refreshed signed
    // URL for the same object) retries instead of reusing the error.
    completer.addEphemeralErrorListener((Object _, StackTrace? _) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    });
    return completer;
  }

  @override
  bool operator ==(Object other) =>
      other is DisplaySizedImage &&
      other.imageProvider == imageProvider &&
      other.box == box &&
      other.fit == fit;

  @override
  int get hashCode => Object.hash(imageProvider, box, fit);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'DisplaySizedImage')}($imageProvider, $box, $fit)';
}

/// Memory-cache key: the wrapped provider's key plus the decode size inputs,
/// so one object shown in two slot sizes is decoded once per size.
@immutable
class DisplaySizedImageKey {
  const DisplaySizedImageKey._(this._providerKey, this._box, this._fit);

  final Object _providerKey;
  final Size _box;
  final BoxFit _fit;

  @override
  bool operator ==(Object other) =>
      other is DisplaySizedImageKey &&
      other._providerKey == _providerKey &&
      other._box == _box &&
      other._fit == _fit;

  @override
  int get hashCode => Object.hash(_providerKey, _box, _fit);
}

/// The decode size for an image of [width]×[height] shown in [box] (physical
/// pixels) with [fit]: the scale that still fills the box for that fit,
/// capped at 1 so an image is never decoded larger than it is stored.
ui.TargetImageSize targetDecodeSize(
  int width,
  int height, {
  required Size box,
  required BoxFit fit,
}) {
  final sx = box.width.isFinite ? box.width / width : null;
  final sy = box.height.isFinite ? box.height / height : null;
  final double? scale;
  if (sx == null || sy == null) {
    // One side is unconstrained: the image is laid out by the other side.
    scale = sx ?? sy;
  } else {
    scale = switch (fit) {
      // fill stretches each axis to the box; the larger scale keeps both
      // axes at or above the box.
      BoxFit.cover || BoxFit.fill => math.max(sx, sy),
      BoxFit.contain || BoxFit.scaleDown => math.min(sx, sy),
      BoxFit.fitWidth => sx,
      BoxFit.fitHeight => sy,
      BoxFit.none => null,
    };
  }
  if (scale == null || scale >= 1) return const ui.TargetImageSize();
  return ui.TargetImageSize(
    width: math.max(1, (width * scale).ceil()),
    height: math.max(1, (height * scale).ceil()),
  );
}
