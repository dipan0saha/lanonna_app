import 'package:flutter/material.dart';

import '../presentation/display_initials.dart';

/// The fallback content of every avatar circle: the [displayInitials] of
/// [name] (or [fallbackText]), or a neutral person glyph when neither is known.
class AvatarInitials extends StatelessWidget {
  const AvatarInitials({
    super.key,
    required this.name,
    this.fallbackText,
    required this.style,
  });

  final String? name;
  final String? fallbackText;

  /// Text style of the initials; the glyph takes its size and color.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final initials = displayInitials(name, fallbackText: fallbackText);
    if (initials != null) return Text(initials, style: style);
    return ExcludeSemantics(
      child: Icon(
        Icons.person_outline,
        size: style?.fontSize,
        color: style?.color,
      ),
    );
  }
}
