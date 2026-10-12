import 'package:flutter/material.dart';

import 'app_semantics.dart';

/// Icon button with a required accessibility label and a stable identifier.
///
/// [IconButton.tooltip] is what TalkBack reads. [AppSemantics] keeps the
/// Maestro id. The icon glyph is excluded from semantics so a character such
/// as "←" is not announced next to the label. Use this instead of a bare
/// [IconButton].
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.semanticsId,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.visualDensity,
    this.padding,
    this.constraints,
  }) : assert(label.length > 0, 'AppIconButton requires a label');

  final String semanticsId;
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? color;
  final VisualDensity? visualDensity;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return AppSemantics.button(
      semanticsId,
      IconButton(
        tooltip: label,
        onPressed: onPressed,
        color: color,
        visualDensity: visualDensity,
        padding: padding,
        constraints: constraints,
        icon: ExcludeSemantics(child: icon),
      ),
      label: label,
    );
  }
}
