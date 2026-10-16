import 'package:flutter/material.dart';

/// Button label text that wraps only on word boundaries (never mid-word).
class AppButtonLabel extends StatelessWidget {
  const AppButtonLabel(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      textAlign: TextAlign.center,
      softWrap: true,
      maxLines: 3,
      overflow: TextOverflow.visible,
      textWidthBasis: TextWidthBasis.longestLine,
    );
  }
}
