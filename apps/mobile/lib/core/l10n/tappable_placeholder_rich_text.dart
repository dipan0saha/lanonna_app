import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A tappable value for one placeholder of a localized message.
class PlaceholderLink {
  const PlaceholderLink({required this.label, required this.onTap});

  /// Localized text shown in place of the placeholder.
  final String label;
  final VoidCallback onTap;
}

/// Renders a localized message whose placeholders are links.
///
/// [message] is called with one opaque token per entry in [links] (pass them
/// straight to the gen-l10n method, in placeholder order). The formatted
/// result is split on those tokens, so links are located by placeholder
/// position, never by searching for words in the rendered sentence. That holds
/// in any locale and when a link label also appears elsewhere in the sentence.
class TappablePlaceholderRichText extends StatefulWidget {
  const TappablePlaceholderRichText({
    super.key,
    required this.message,
    required this.links,
    this.style,
    this.linkStyle,
    this.textAlign,
  });

  final String Function(List<String> tokens) message;
  final List<PlaceholderLink> links;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign? textAlign;

  @override
  State<TappablePlaceholderRichText> createState() =>
      _TappablePlaceholderRichTextState();
}

// Private-use code points cannot occur in translated copy.
const _open = '\uE000';
const _close = '\uE001';
final _tokenPattern = RegExp('$_open(\\d+)$_close');

String _token(int index) => '$_open$index$_close';

class _TappablePlaceholderRichTextState
    extends State<TappablePlaceholderRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _syncRecognizers() {
    while (_recognizers.length > widget.links.length) {
      _recognizers.removeLast().dispose();
    }
    while (_recognizers.length < widget.links.length) {
      _recognizers.add(TapGestureRecognizer());
    }
    for (var i = 0; i < widget.links.length; i++) {
      _recognizers[i].onTap = widget.links[i].onTap;
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncRecognizers();
    final formatted = widget.message([
      for (var i = 0; i < widget.links.length; i++) _token(i),
    ]);
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in _tokenPattern.allMatches(formatted)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: formatted.substring(cursor, match.start)));
      }
      final index = int.parse(match.group(1)!);
      children.add(
        TextSpan(
          text: widget.links[index].label,
          style: widget.linkStyle,
          recognizer: _recognizers[index],
          mouseCursor: SystemMouseCursors.click,
        ),
      );
      cursor = match.end;
    }
    if (cursor < formatted.length) {
      children.add(TextSpan(text: formatted.substring(cursor)));
    }
    return Text.rich(
      TextSpan(style: widget.style, children: children),
      textAlign: widget.textAlign,
    );
  }
}
