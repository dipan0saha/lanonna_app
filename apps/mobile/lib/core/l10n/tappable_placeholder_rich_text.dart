import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// One tappable segment inside a [TappablePlaceholderRichText] template.
class TappableTextSpan {
  const TappableTextSpan({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;
}

/// Renders [template] (e.g. from gen-l10n with placeholder values filled in) and
/// makes each [spans] entry tappable where its [TappableTextSpan.text] appears.
class TappablePlaceholderRichText extends StatelessWidget {
  const TappablePlaceholderRichText({
    super.key,
    required this.template,
    required this.spans,
    this.style,
    this.linkStyle,
    this.textAlign,
  });

  final String template;
  final List<TappableTextSpan> spans;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final ordered = [...spans]..sort(
      (a, b) => template.indexOf(a.text).compareTo(template.indexOf(b.text)),
    );

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final span in ordered) {
      final index = template.indexOf(span.text, cursor);
      if (index < 0) continue;
      if (index > cursor) {
        children.add(TextSpan(text: template.substring(cursor, index), style: style));
      }
      children.add(
        TextSpan(
          text: span.text,
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = span.onTap,
        ),
      );
      cursor = index + span.text.length;
    }
    if (cursor < template.length) {
      children.add(TextSpan(text: template.substring(cursor), style: style));
    }

    return Text.rich(
      TextSpan(children: children, style: style),
      textAlign: textAlign,
    );
  }
}
