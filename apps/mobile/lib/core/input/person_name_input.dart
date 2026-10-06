import 'package:flutter/services.dart';

/// Keyboard hint for person-name fields (baby names, suggestions, profile name).
const TextCapitalization personNameTextCapitalization = TextCapitalization.words;

/// Input formatters for person-name fields.
const List<TextInputFormatter> personNameInputFormatters = [
  TitleCaseWordsInputFormatter(),
];

/// Normalizes a person name for submit (trim + title-case each word).
String formatPersonName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final words = trimmed.split(RegExp(r'\s+'));
  return words.map(_titleCaseWord).join(' ');
}

/// Title-cases each word; preserves whitespace between words.
String titleCaseWordsPreserveSpacing(String text) {
  if (text.isEmpty) return text;

  final buffer = StringBuffer();
  var i = 0;
  while (i < text.length) {
    while (i < text.length && _isWhitespace(text[i])) {
      buffer.write(text[i]);
      i++;
    }
    if (i >= text.length) break;

    final start = i;
    while (i < text.length && !_isWhitespace(text[i])) {
      i++;
    }
    buffer.write(_titleCaseWord(text.substring(start, i)));
  }
  return buffer.toString();
}

bool _isWhitespace(String char) => char.trim().isEmpty;

String _titleCaseWord(String word) {
  if (word.isEmpty) return word;
  if (word.length == 1) return word.toUpperCase();
  return word[0].toUpperCase() + word.substring(1).toLowerCase();
}

/// Enforces title-case per word while the user types or pastes.
class TitleCaseWordsInputFormatter extends TextInputFormatter {
  const TitleCaseWordsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = titleCaseWordsPreserveSpacing(newValue.text);
    if (formatted == newValue.text) {
      return newValue;
    }

    final delta = formatted.length - newValue.text.length;
    var offset = newValue.selection.end + delta;
    offset = offset.clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
