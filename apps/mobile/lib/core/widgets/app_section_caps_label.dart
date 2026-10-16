import 'package:flutter/material.dart';

import '../theme/la_nonna_theme.dart';

/// Grey spaced caps section label (WHEN, LOCATION, ALL PHOTOS).
class AppSectionCapsLabel extends StatelessWidget {
  const AppSectionCapsLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = context.textStyles.labelSmall;
    if (trailing == null) {
      return Text(text.toUpperCase(), style: style);
    }
    return Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: style)),
        trailing!,
      ],
    );
  }
}
