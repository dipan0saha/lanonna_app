import 'package:flutter/material.dart';

/// Stroke chat bubble matching prototype gallery grid (11×11 in 24×24 viewBox).
class GalleryCommentGlyph extends StatelessWidget {
  const GalleryCommentGlyph({super.key, this.size = 11, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CommentGlyphPainter(
          color: color,
          strokeWidth: size * 1.8 / 24,
        ),
      ),
    );
  }
}

class _CommentGlyphPainter extends CustomPainter {
  _CommentGlyphPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24;
    final sy = size.height / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(4 * sx, 5 * sy)
      ..lineTo(20 * sx, 5 * sy)
      ..lineTo(21 * sx, 6 * sy)
      ..lineTo(21 * sx, 15 * sy)
      ..lineTo(20 * sx, 16 * sy)
      ..lineTo(9 * sx, 16 * sy)
      ..lineTo(5 * sx, 20 * sy)
      ..lineTo(5 * sx, 16 * sy)
      ..lineTo(4 * sx, 16 * sy)
      ..lineTo(4 * sx, 5 * sy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CommentGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Stroke squish / wave hand matching prototype gallery grid.
class GallerySquishGlyph extends StatelessWidget {
  const GallerySquishGlyph({super.key, this.size = 11, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SquishGlyphPainter(
          color: color,
          strokeWidth: size * 1.4 / 24,
        ),
      ),
    );
  }
}

class _SquishGlyphPainter extends CustomPainter {
  _SquishGlyphPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24;
    final sy = size.height / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void finger(double x, double yTop, double yBottom) {
      canvas.drawLine(
        Offset(x * sx, yTop * sy),
        Offset(x * sx, yBottom * sy),
        paint,
      );
    }

    finger(8.5, 12, 7);
    finger(11.5, 10, 6);
    finger(14.5, 10, 7);
    finger(17.5, 11, 9);

    final palm = Path()
      ..moveTo(5 * sx, 13.5 * sy)
      ..quadraticBezierTo(10 * sx, 18 * sy, 16 * sx, 17 * sy)
      ..quadraticBezierTo(19 * sx, 16 * sy, 18.6 * sx, 11 * sy);
    canvas.drawPath(palm, paint);
  }

  @override
  bool shouldRepaint(covariant _SquishGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
