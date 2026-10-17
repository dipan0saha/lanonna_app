import 'package:lanonna/l10n/app_localizations.dart';

String? validateEmail(AppLocalizations l10n, String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return l10n.validationEmailRequired;
  final pattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  if (!pattern.hasMatch(email)) return l10n.validationEmailInvalid;
  return null;
}

String? validatePassword(AppLocalizations l10n, String? value) {
  final password = value ?? '';
  if (password.length < 6) return l10n.validationPasswordTooShort;
  if (!RegExp(r'[\d\W]').hasMatch(password)) {
    return l10n.validationPasswordNeedsSymbol;
  }
  return null;
}

String? validateDisplayName(AppLocalizations l10n, String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return l10n.validationDisplayNameRequired;
  if (name.length > 100) return l10n.validationDisplayNameTooLong;
  return null;
}

String? validateOnboardingFirstName(AppLocalizations l10n, String? value) =>
    _required(value, l10n.validationFirstNameRequired);

String? validateOnboardingLastName(AppLocalizations l10n, String? value) =>
    _required(value, l10n.validationLastNameRequired);

/// Full profile display name from first + last (length cap via [validateDisplayName]).
String? validateOnboardingProfileDisplayName(
  AppLocalizations l10n,
  String firstName,
  String lastName,
) {
  final combined = '${firstName.trim()} ${lastName.trim()}'.trim();
  return validateDisplayName(l10n, combined);
}

final _optionalPhoneAllowed = RegExp(r'^[0-9+\-() ]+$');

/// Empty is allowed. Otherwise digits, spaces, and `+ - ( )`, with 7–20 digits.
/// A `+` may appear only once, at the start (same rule as the profile API).
String? validateOptionalPhone(AppLocalizations l10n, String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final valid = _optionalPhoneAllowed.hasMatch(raw) &&
      (!raw.contains('+') || raw.startsWith('+')) &&
      '+'.allMatches(raw).length <= 1 &&
      digits.length >= 7 &&
      digits.length <= 20;
  return valid ? null : l10n.validationPhoneInvalid;
}

String? validateTermsAccepted(AppLocalizations l10n, bool? value) {
  if (value != true) return l10n.validationTermsRequired;
  return null;
}

String? validateOnboardingRelationshipToBaby(
  AppLocalizations l10n,
  String? value,
) =>
    _required(value, l10n.validationRelationshipRequired);

String? validateFunNameSuggestion(AppLocalizations l10n, String? value) =>
    _required(value, l10n.validationNameRequired);

String? validateRegistryItemName(AppLocalizations l10n, String? value) =>
    _required(value, l10n.validationItemNameRequired);

String? validateRegistryShippingLine1(AppLocalizations l10n, String? value) =>
    _required(value, l10n.validationStreetRequired);

String? validateRegistryShippingCity(AppLocalizations l10n, String? value) =>
    _required(value, l10n.validationCityRequired);

String? validateRegistryShippingPostalCode(
  AppLocalizations l10n,
  String? value,
) =>
    _required(value, l10n.validationPostalCodeRequired);

String? validateCountryCode(AppLocalizations l10n, String? code) =>
    _required(code, l10n.validationCountryRequired);

String? _required(String? value, String message) =>
    value == null || value.trim().isEmpty ? message : null;

const _maxOptionalHttpUrlLength = 2048;

String? validateOptionalHttpUrl(AppLocalizations l10n, String? value) =>
    _isValidOptionalHttpUrl(value) ? null : l10n.validationUrlInvalid;

/// Normalizes empty to null; bare domains get `https://`.
///
/// Callers validate first with [validateOptionalHttpUrl]; an invalid value
/// here is a programming error and throws [FormatException].
String? normalizeOptionalHttpUrl(String? value) {
  if (!_isValidOptionalHttpUrl(value)) {
    throw const FormatException('invalid_optional_http_url');
  }
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (!raw.contains('://')) {
    return 'https://$raw';
  }
  return raw;
}

bool _isValidOptionalHttpUrl(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return true;
  if (raw.length > _maxOptionalHttpUrlLength) return false;
  if (raw.contains(' ')) return false;

  final withScheme = raw.contains('://') ? raw : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasScheme) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  final host = uri.host;
  if (host.isEmpty) return false;
  return host == 'localhost' || host.contains('.');
}
