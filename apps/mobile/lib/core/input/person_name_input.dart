import 'package:flutter/services.dart';

/// Keyboard hint for person-name fields (baby names, suggestions, profile name).
const TextCapitalization personNameTextCapitalization = TextCapitalization.words;

/// Input formatters for person-name fields.
const List<TextInputFormatter> personNameInputFormatters = [
  PersonNameInputFormatter(),
];

/// Normalizes a person name for submit (trim, collapse spaces, light capitalization).
String formatPersonName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final collapsed = trimmed.replaceAll(RegExp(r'\s+'), ' ');
  return applyPersonNameCapitalization(collapsed);
}

/// Capitalizes the first letter of each name part; preserves other casing (McKenzie, QA…).
///
/// Part boundaries: whitespace, hyphen, apostrophe.
String applyPersonNameCapitalization(String text) {
  if (text.isEmpty) return text;

  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    final atPartStart = i == 0 || _isNamePartBoundary(text[i - 1]);
    if (atPartStart && _isLowercaseLetter(ch)) {
      buffer.write(ch.toUpperCase());
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

bool _isNamePartBoundary(String char) =>
    char == '-' || char == "'" || char == '\u2019' || _isWhitespace(char);

bool _isWhitespace(String char) => char.trim().isEmpty;

bool _isLetter(String char) =>
    char.isNotEmpty && char.toUpperCase() != char.toLowerCase();

bool _isLowercaseLetter(String char) =>
    _isLetter(char) && char == char.toLowerCase();

/// Applies [applyPersonNameCapitalization] while the user types or pastes.
class PersonNameInputFormatter extends TextInputFormatter {
  const PersonNameInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = applyPersonNameCapitalization(newValue.text);
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
