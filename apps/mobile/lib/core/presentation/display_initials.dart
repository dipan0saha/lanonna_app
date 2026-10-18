import 'package:flutter/widgets.dart';

/// The one initials rule for every avatar in the app.
///
/// Up to two uppercase initials: the first letters of the first two words of
/// the display [name], else the first letter of [fallbackText] (the sign-in
/// email for the signed-in user). `null` when both are blank: show the neutral
/// person glyph ([AvatarInitials]), never the initial of a placeholder word.
///
/// Works on user-perceived characters, so accents and emoji stay whole.
String? displayInitials(String? name, {String? fallbackText}) {
  final primary = name?.trim() ?? '';
  if (primary.isNotEmpty) {
    final words = primary.split(RegExp(r'\s+'));
    final first = _firstCharacter(words[0]);
    if (words.length >= 2) return '$first${_firstCharacter(words[1])}';
    return first;
  }
  final fallback = fallbackText?.trim() ?? '';
  if (fallback.isEmpty) return null;
  return _firstCharacter(fallback);
}

String _firstCharacter(String word) => word.characters.first.toUpperCase();
