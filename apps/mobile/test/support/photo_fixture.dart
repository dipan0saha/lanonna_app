import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A deterministic, photo-like test image (no binary fixture in the repo).
///
/// Flat fills compress to almost nothing and pure noise to almost nothing
/// less, so neither says how the upload encoder behaves on a real camera
/// photo. This mixes what a photo has: smooth light gradients, mid-scale
/// texture (fractal value noise), hard-edged objects and fine sensor grain.
/// The same [seed] always gives the same pixels, so sizes are comparable
/// across runs.
img.Image photoLikeImage({
  int width = 2048,
  int height = 1536,
  int seed = 65,
}) {
  final rnd = math.Random(seed);
  final lattice = Float64List(257 * 257);
  for (var i = 0; i < lattice.length; i++) {
    lattice[i] = rnd.nextDouble();
  }
  double valueNoise(double x, double y) {
    final xi = x.floor();
    final yi = y.floor();
    final xf = x - xi;
    final yf = y - yi;
    final u = xf * xf * (3 - 2 * xf);
    final v = yf * yf * (3 - 2 * yf);
    double at(int gx, int gy) => lattice[(gy & 255) * 257 + (gx & 255)];
    final a = at(xi, yi);
    final b = at(xi + 1, yi);
    final c = at(xi, yi + 1);
    final d = at(xi + 1, yi + 1);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  }

  double fbm(double x, double y) {
    var sum = 0.0;
    var amp = 0.5;
    var freq = 1.0;
    for (var o = 0; o < 6; o++) {
      sum += amp * valueNoise(x * freq, y * freq);
      amp *= 0.62;
      freq *= 2.03;
    }
    return sum;
  }

  final objects = List.generate(14, (_) {
    return (
      cx: rnd.nextDouble() * width,
      cy: rnd.nextDouble() * height,
      r: (0.04 + rnd.nextDouble() * 0.12) * width,
      rect: rnd.nextBool(),
      color: [rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256)],
    );
  });

  final image = img.Image(width: width, height: height);
  final scale = 6.0 / width;
  for (var y = 0; y < height; y++) {
    final sky = y / height;
    for (var x = 0; x < width; x++) {
      final n = fbm(x * scale, y * scale);
      final h = fbm(x * scale + 40, y * scale + 40);
      final t = fbm(x * scale * 24 + 90, y * scale * 24 + 90) - 0.5;
      var r = 70 + 120 * sky + 90 * (n - 0.5) * 2 + 40 * (h - 0.5) + 70 * t;
      var g = 90 + 80 * (1 - sky) + 90 * (n - 0.5) * 2 + 60 * t;
      var b = 150 - 60 * sky + 70 * (h - 0.5) * 2 + 50 * t;
      for (final o in objects) {
        final dx = (x - o.cx).abs();
        final dy = (y - o.cy).abs();
        final inside = o.rect
            ? dx < o.r && dy < o.r * 0.6
            : dx * dx + dy * dy < o.r * o.r;
        if (inside) {
          final shade = 0.75 + 0.5 * (n - 0.5) + 0.4 * t;
          r = o.color[0] * shade;
          g = o.color[1] * shade;
          b = o.color[2] * shade;
        }
      }
      final grain = (rnd.nextDouble() + rnd.nextDouble() - 1) * 10;
      image.setPixelRgb(
        x,
        y,
        (r + grain).clamp(0, 255).toInt(),
        (g + grain).clamp(0, 255).toInt(),
        (b + grain).clamp(0, 255).toInt(),
      );
    }
  }
  return image;
}

/// [photoLikeImage] as the JPEG an image picker hands back (q85).
Uint8List photoLikeJpeg({int width = 2048, int height = 1536, int seed = 65}) =>
    img.encodeJpg(
      photoLikeImage(width: width, height: height, seed: seed),
      quality: 85,
    );
