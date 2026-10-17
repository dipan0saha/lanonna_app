import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The value shown for one placeholder of a localized message.
///
/// A span with [onTap] is a link; [style] overrides the widget's
/// `placeholderStyle` for this span only.
class MessagePlaceholder {
  const MessagePlaceholder({required this.label, this.onTap, this.style});

  /// Localized text shown in place of the placeholder.
  final String label;
  final VoidCallback? onTap;
  final TextStyle? style;
}

/// Renders a localized message whose placeholders are styled spans (links,
/// bold names, …).
///
/// [message] is called with one opaque token per entry in [placeholders]
/// (pass them straight to the gen-l10n method, in placeholder order). The
/// formatted result is split on those tokens, so spans are located by
/// placeholder position, never by searching for words in the rendered
/// sentence. That holds in any locale, when ICU `select` / `plural` moves the
/// placeholder, and when a label also appears elsewhere in the sentence.
class PlaceholderRichText extends StatefulWidget {
  const PlaceholderRichText({
    super.key,
    required this.message,
    required this.placeholders,
    this.style,
    this.placeholderStyle,
    this.textAlign,
  });

  final String Function(List<String> tokens) message;
  final List<MessagePlaceholder> placeholders;
  final TextStyle? style;
  final TextStyle? placeholderStyle;
  final TextAlign? textAlign;

  /// The message as plain text (placeholders filled with their labels), for
  /// semantics labels and logs.
  static String plainText(
    String Function(List<String> tokens) message,
    List<MessagePlaceholder> placeholders,
  ) =>
      message([for (final p in placeholders) p.label]);

  @override
  State<PlaceholderRichText> createState() => _PlaceholderRichTextState();
}

// Private-use code points cannot occur in translated copy.
const _open = '\uE000';
const _close = '\uE001';
final _tokenPattern = RegExp('$_open(\\d+)$_close');

String _token(int index) => '$_open$index$_close';

class _PlaceholderRichTextState extends State<PlaceholderRichText> {
  final List<TapGestureRecognizer?> _recognizers = [];

  void _syncRecognizers() {
    final spans = widget.placeholders;
    while (_recognizers.length > spans.length) {
      _recognizers.removeLast()?.dispose();
    }
    while (_recognizers.length < spans.length) {
      _recognizers.add(null);
    }
    for (var i = 0; i < spans.length; i++) {
      final onTap = spans[i].onTap;
      if (onTap == null) {
        _recognizers[i]?.dispose();
        _recognizers[i] = null;
      } else {
        (_recognizers[i] ??= TapGestureRecognizer()).onTap = onTap;
      }
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncRecognizers();
    final formatted = widget.message([
      for (var i = 0; i < widget.placeholders.length; i++) _token(i),
    ]);
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in _tokenPattern.allMatches(formatted)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: formatted.substring(cursor, match.start)));
      }
      final index = int.parse(match.group(1)!);
      final span = widget.placeholders[index];
      final recognizer = _recognizers[index];
      children.add(
        TextSpan(
          text: span.label,
          style: span.style ?? widget.placeholderStyle,
          recognizer: recognizer,
          mouseCursor:
              recognizer == null ? null : SystemMouseCursors.click,
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
