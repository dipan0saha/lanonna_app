import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/calendar/domain/rsvp_status_labels.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('rsvpStatusLabel maps API codes', () {
    expect(rsvpStatusLabel(l10n, 'going'), 'Going');
    expect(rsvpStatusLabel(l10n, 'maybe'), 'Maybe');
    expect(rsvpStatusLabel(l10n, 'cant_go'), "Can't go");
  });
}
