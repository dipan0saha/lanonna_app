import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('babyDisplayName uses the name as entered, never prefixed', () {
    expect(babyDisplayName('Baby Parker', l10n), 'Baby Parker');
    expect(babyDisplayName('  Parker ', l10n), 'Parker');
    expect(babyDisplayName('', l10n), 'your baby');
    expect(babyDisplayName(null, l10n), 'your baby');
  });
}
