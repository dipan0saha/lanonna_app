import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  test('inviteCoOwnerAccessBody uses a single possessive apostrophe', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final body = l10n.inviteCoOwnerAccessBody('Luna', 'Alex');

    expect(body, contains("Luna's profile"));
    expect(body, isNot(contains("Luna''s")));
  });
}
