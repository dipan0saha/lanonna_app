import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

void main() {
  test('delete account copy matches FR-SET-005', () {
    final l10n = AppLocalizationsEn();
    expect(l10n.deleteAccountBody, contains('solely owned by your account will also be deleted'));
    expect(l10n.deleteAccountBody, contains('co owner will not be deleted'));
    expect(l10n.deleteAccountButton, 'Delete my account');
  });
}
