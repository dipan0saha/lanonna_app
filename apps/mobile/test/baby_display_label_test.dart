import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('babyDisplayName uses the name as entered, never prefixed', () {
    expect(babyDisplayName(l10n, 'Baby Parker'), 'Baby Parker');
    expect(babyDisplayName(l10n, '  Parker '), 'Parker');
    expect(babyDisplayName(l10n, ''), 'your baby');
    expect(babyDisplayName(l10n, null), 'your baby');
  });
}
