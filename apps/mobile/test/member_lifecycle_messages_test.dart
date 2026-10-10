import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/features/account/domain/member_lifecycle_messages.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('maps sole_owner_cannot_leave to explanatory copy', () {
    final msg = memberLifecycleErrorMessage(
      l10n,
      ApiException(
        'bad',
        statusCode: 400,
        detail: {'error': 'sole_owner_cannot_leave', 'message': 'x'},
      ),
    );
    expect(msg, l10n.memberSoleOwnerLeaveBody);
  });
}
