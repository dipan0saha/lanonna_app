import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/constants/first_moment_presets.dart';
import 'package:lanonna/core/input/prose_sentence_input.dart';
import 'package:lanonna/core/l10n/first_moment_preset_labels.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

/// `assets/calendar/event_suggestions.json` is the source of truth for event
/// titles (#424). The API side is `test_first_moment_preset_parity.py`.
Map<String, String> _catalogTitles() {
  final data =
      jsonDecode(
            File('assets/calendar/event_suggestions.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return {
    for (final rows in data.values)
      for (final row in rows as List<dynamic>)
        (row as Map<String, dynamic>)['id'] as String: row['title'] as String,
  };
}

void main() {
  final catalog = _catalogTitles();

  test('event form submit keeps every catalog title as written', () {
    for (final title in catalog.values) {
      expect(formatProseSentence(title), title);
    }
  });

  test('first-moment event chips use the catalog title', () {
    final l10n = AppLocalizationsEn();
    for (final preset in [
      ...FirstMomentPresets.expectingEvents,
      ...FirstMomentPresets.bornEvents,
    ]) {
      final title = catalog[preset.id];
      if (title != null) {
        expect(l10n.firstMomentEventLabel(preset.id), title, reason: preset.id);
      }
    }
  });
}
