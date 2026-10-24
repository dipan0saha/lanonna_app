import 'package:flutter/services.dart';

/// Keyboard hint for captions, comments, titles, and other prose fields.
const TextCapitalization proseSentenceTextCapitalization =
    TextCapitalization.sentences;

/// Input formatters for prose / sentence-style fields.
const List<TextInputFormatter> proseSentenceInputFormatters = [
  SentenceCaseInputFormatter(),
];

/// Normalizes prose for submit (trim + sentence-case boundaries).
String formatProseSentence(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return applySentenceCase(trimmed);
}

/// Uppercases the first letter of each sentence (text start, after `.` `!` `?`
/// boundaries, and new lines). A sentence that starts with a digit is already
/// started, so nothing in it is uppercased ("20-week anatomy scan", "3.5 kg").
String applySentenceCase(String text) {
  if (text.isEmpty) return text;

  final buffer = StringBuffer();
  var capitalizeNext = true;
  var i = 0;

  while (i < text.length) {
    final char = text[i];

    if (capitalizeNext && _isLetter(char)) {
      buffer.write(char.toUpperCase());
      capitalizeNext = false;
      i++;
      continue;
    }
    if (capitalizeNext && _isDigit(char)) {
      capitalizeNext = false;
    }

    buffer.write(char);

    if (_isSentenceTerminator(char) || char == '\n') {
      capitalizeNext = true;
      if (_isSentenceTerminator(char)) {
        i++;
        while (i < text.length && _isClosingAfterTerminator(text[i])) {
          buffer.write(text[i]);
          i++;
        }
        continue;
      }
    }

    i++;
  }

  return buffer.toString();
}

bool _isLetter(String char) {
  if (char.isEmpty) return false;
  return RegExp(r'[A-Za-z]').hasMatch(char);
}

bool _isDigit(String char) =>
    char.isNotEmpty && RegExp(r'[0-9]').hasMatch(char);

bool _isSentenceTerminator(String char) =>
    char == '.' || char == '!' || char == '?';

bool _isClosingAfterTerminator(String char) =>
    char == '"' || char == "'" || char == ')' || char == ']';

/// Enforces sentence-case while the user types or pastes.
class SentenceCaseInputFormatter extends TextInputFormatter {
  const SentenceCaseInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = applySentenceCase(newValue.text);
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
