import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  test('inviteCoOwnerAccessBody uses a single possessive apostrophe', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final body = l10n.inviteCoOwnerAccessBody('Luna', 'Alex');

    expect(body, contains("Luna's profile"));
    expect(body, isNot(contains("Luna''s")));
  });

  // gen-l10n runs without `use-escaping`, so quotes in ARB values are literal:
  // ICU-style `''` escaping renders as two apostrophes on screen.
  test('no ARB message uses ICU quote escaping', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final offenders = [
      for (final e in arb.entries)
        if (!e.key.startsWith('@') && e.value is String &&
            (e.value as String).contains("''"))
          e.key,
    ];
    expect(offenders, isEmpty);
  });
}
