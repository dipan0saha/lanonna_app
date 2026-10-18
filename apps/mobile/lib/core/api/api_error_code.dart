import 'package:lanonna/l10n/app_localizations.dart';

/// Stable `detail.error` codes the API returns with every error.
///
/// Mirrors `ErrorCode` in `services/api/src/lanonna_api/domain/errors.py`
/// (`services/api/tests/test_error_code_parity.py` keeps the two in sync).
/// The server's English `detail.message` is diagnostic only; users see
/// [userMessage] in their locale.
enum ApiErrorCode {
  internalError('internal_error'),
  serviceUnavailable('service_unavailable'),
  invalidRequest('invalid_request'),
  notFound('not_found'),
  forbidden('forbidden'),
  conflict('conflict'),
  unauthenticated('unauthenticated'),
  appCheckFailed('app_check_failed'),
  rateLimited('rate_limited'),
  userDeleted('user_deleted'),
  membershipEnded('membership_ended'),
  notMember('not_member'),
  targetNotMember('target_not_member'),
  lastOwner('last_owner'),
  soleOwnerCannotLeave('sole_owner_cannot_leave'),
  cannotDeleteSharedBaby('cannot_delete_shared_baby'),
  useLeaveEndpoint('use_leave_endpoint'),
  expired('expired'),
  revoked('revoked'),
  alreadyUsed('already_used'),
  maxOwners('max_owners'),
  emailMismatch('email_mismatch'),
  emailNotVerified('email_not_verified'),
  babyProfileRequired('baby_profile_required'),
  profileIncomplete('profile_incomplete'),
  displayNameRequired('display_name_required'),
  invalidPhone('invalid_phone'),
  invalidBirthDate('invalid_birth_date'),
  birthDateInFuture('birth_date_in_future'),
  invalidUrl('invalid_url'),
  textTooLong('text_too_long'),
  invalidBirthTime('invalid_birth_time'),
  commentRequired('comment_required'),
  unsupportedMediaType('unsupported_media_type'),
  fileTooLarge('file_too_large'),
  funClosed('fun_closed'),
  predictionsClosed('predictions_closed'),
  nameRequired('name_required'),
  duplicateNameSuggestion('duplicate_name_suggestion'),
  nameAlreadySuggested('name_already_suggested'),
  itemNameRequired('item_name_required'),
  alreadyOnRegistry('already_on_registry'),
  registryItemPurchased('registry_item_purchased'),
  shippingAddressIncomplete('shipping_address_incomplete'),
  alreadyOnCalendar('already_on_calendar'),
  eventEndBeforeStart('event_end_before_start'),
  emailQueueFailed('email_queue_failed'),
  exportQueueFailed('export_queue_failed'),
  // Client-side codes for failures that never reached the API.
  networkUnavailable('network_unavailable'),
  networkTimeout('network_timeout');

  const ApiErrorCode(this.apiValue);

  final String apiValue;

  /// Codes the app creates itself; excluded from the API parity check.
  static const Set<ApiErrorCode> clientOnly = {
    networkUnavailable,
    networkTimeout,
  };

  static ApiErrorCode? fromApi(String? raw) {
    for (final code in values) {
      if (code.apiValue == raw) return code;
    }
    return null;
  }

  /// Category fallback when a response has no code this build knows.
  static ApiErrorCode forStatus(int? statusCode) => switch (statusCode) {
        400 || 422 => invalidRequest,
        401 => unauthenticated,
        403 => forbidden,
        404 || 410 => notFound,
        409 => conflict,
        429 => rateLimited,
        503 => serviceUnavailable,
        _ => internalError,
      };

  /// Localized copy. [params] is the error's `detail.params`, when sent.
  String userMessage(
    AppLocalizations l10n, [
    Map<String, dynamic> params = const {},
  ]) =>
      switch (this) {
        internalError => l10n.errorGeneric,
        serviceUnavailable => l10n.errorServiceUnavailable,
        invalidRequest => l10n.errorInvalidRequest,
        notFound => l10n.errorNotFound,
        forbidden => l10n.errorForbidden,
        conflict => l10n.errorConflict,
        unauthenticated => l10n.errorUnauthenticated,
        appCheckFailed => l10n.errorAppCheckFailed,
        rateLimited => l10n.errorRateLimited,
        userDeleted => l10n.errorAccountDeleted,
        membershipEnded => l10n.membershipEndedMessage,
        notMember => l10n.errorNotMember,
        targetNotMember => l10n.errorTargetNotMember,
        lastOwner => l10n.errorLastOwner,
        soleOwnerCannotLeave => l10n.memberSoleOwnerLeaveBody,
        cannotDeleteSharedBaby => l10n.errorCannotDeleteSharedBaby,
        useLeaveEndpoint => l10n.errorUseLeaveProfile,
        expired => l10n.inviteErrorExpired,
        revoked => l10n.inviteErrorRevoked,
        alreadyUsed => l10n.inviteErrorAlreadyUsed,
        maxOwners => l10n.inviteErrorMaxOwners,
        emailMismatch => l10n.inviteErrorEmailMismatch,
        emailNotVerified => l10n.errorEmailNotVerified,
        babyProfileRequired => l10n.errorBabyProfileRequired,
        profileIncomplete => l10n.errorProfileIncomplete,
        displayNameRequired => l10n.validationDisplayNameRequired,
        invalidPhone => l10n.validationPhoneInvalid,
        invalidBirthDate => l10n.errorInvalidBirthDate,
        birthDateInFuture => l10n.homeDateOfBirthCannotBe,
        invalidUrl => l10n.validationUrlInvalid,
        textTooLong => switch (params['max_length']) {
            final int maxLength => l10n.errorTextTooLong(maxLength),
            _ => l10n.errorInvalidRequest,
          },
        invalidBirthTime => l10n.errorInvalidBirthTime,
        commentRequired => l10n.errorCommentRequired,
        unsupportedMediaType => l10n.errorUnsupportedMediaType,
        fileTooLarge => l10n.errorFileTooLarge,
        funClosed => l10n.errorFunClosed,
        predictionsClosed => l10n.errorPredictionsClosed,
        nameRequired => l10n.validationNameRequired,
        duplicateNameSuggestion => l10n.errorDuplicateNameSuggestion,
        nameAlreadySuggested => l10n.errorNameAlreadySuggested,
        itemNameRequired => l10n.validationItemNameRequired,
        alreadyOnRegistry => l10n.errorAlreadyOnRegistry,
        registryItemPurchased => l10n.errorRegistryItemPurchased,
        shippingAddressIncomplete => l10n.errorShippingAddressIncomplete,
        alreadyOnCalendar => l10n.errorAlreadyOnCalendar,
        eventEndBeforeStart => l10n.errorEventEndBeforeStart,
        emailQueueFailed => l10n.errorEmailQueueFailed,
        exportQueueFailed => l10n.errorExportQueueFailed,
        networkUnavailable => l10n.errorOffline,
        networkTimeout => l10n.errorNetwork,
      };
}
