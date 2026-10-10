import 'package:lanonna/l10n/app_localizations.dart';

import '../../../core/api/api_exception.dart';

String memberLifecycleErrorMessage(AppLocalizations l10n, ApiException error) {
  final code = error.detail?['error'] as String?;
  switch (code) {
    case 'sole_owner_cannot_leave':
      return l10n.memberSoleOwnerLeaveBody;
    case 'last_owner':
      return l10n.memberSoleOwnerLeaveBody;
    case 'use_leave_endpoint':
      return l10n.memberLeaveProfile;
    case 'target_not_member':
    case 'not_member':
      return error.detail?['message'] as String? ?? error.message;
    default:
      return error.detail?['message'] as String? ?? error.message;
  }
}
