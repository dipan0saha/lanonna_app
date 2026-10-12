import 'package:flutter/material.dart';

import 'app_semantics.dart';

/// Icon button with a required accessibility label and a stable identifier.
///
/// [IconButton.tooltip] is what TalkBack reads. [AppSemantics] keeps the
/// Maestro id. Use this instead of a bare [IconButton] for toolbar and
/// row actions.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.semanticsId,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String semanticsId;
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppSemantics.button(
      semanticsId,
      IconButton(tooltip: label, onPressed: onPressed, icon: icon),
      label: label,
    );
  }
}
