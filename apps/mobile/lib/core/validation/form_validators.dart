String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Email is required';
  final pattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  if (!pattern.hasMatch(email)) return 'Enter a valid email';
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.length < 6) return 'Password must be at least 6 characters';
  if (!RegExp(r'[\d\W]').hasMatch(password)) {
    return 'Include a number or symbol';
  }
  return null;
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Display name is required';
  if (name.length > 100) return 'Display name is too long';
  return null;
}

String? validateOnboardingFirstName(String? value) =>
    validateRequiredTrimmed(value, fieldLabel: 'First name');

String? validateOnboardingLastName(String? value) =>
    validateRequiredTrimmed(value, fieldLabel: 'Last name');

/// Full profile display name from first + last (length cap via [validateDisplayName]).
String? validateOnboardingProfileDisplayName(String firstName, String lastName) {
  final combined = '${firstName.trim()} ${lastName.trim()}'.trim();
  return validateDisplayName(combined);
}

String? validateTermsAccepted(bool? value) {
  if (value != true) return 'Please accept the terms to continue';
  return null;
}

String? validateOnboardingRelationshipToBaby(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Select your relationship to baby';
  }
  return null;
}

String? validateFunNameSuggestion(String? value) =>
    validateRequiredTrimmed(value, fieldLabel: 'Name');

String? validateRequiredTrimmed(String? value, {required String fieldLabel}) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldLabel is required';
  }
  return null;
}

String? validateRegistryItemName(String? value) =>
    validateRequiredTrimmed(value, fieldLabel: 'Item name');

String? validateRegistryShippingLine1(String? value) =>
    validateRequiredTrimmed(value, fieldLabel: 'Street address');

String? validateRegistryShippingCity(String? value) =>
    validateRequiredTrimmed(value, fieldLabel: 'City');

String? validateRegistryShippingPostalCode(String? value) =>
    validateRequiredTrimmed(value, fieldLabel: 'Zip / Postal code');

String? validateCountryCode(String? code) {
  if (code == null || code.trim().isEmpty) {
    return 'Select a country';
  }
  return null;
}

const invalidOptionalHttpUrl = 'Enter a valid link, e.g. https://…';

const _maxOptionalHttpUrlLength = 2048;

String? validateOptionalHttpUrl(String? value) {
  return _optionalHttpUrlValidationError(value);
}

/// Normalizes empty to null; bare domains get `https://`. Throws [FormatException].
String? normalizeOptionalHttpUrl(String? value) {
  final error = _optionalHttpUrlValidationError(value);
  if (error != null) {
    throw FormatException(error);
  }
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (!raw.contains('://')) {
    return 'https://$raw';
  }
  return raw;
}

String? _optionalHttpUrlValidationError(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.length > _maxOptionalHttpUrlLength) return invalidOptionalHttpUrl;
  if (raw.contains(' ')) return invalidOptionalHttpUrl;

  final withScheme = raw.contains('://') ? raw : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasScheme) return invalidOptionalHttpUrl;
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return invalidOptionalHttpUrl;
  }
  final host = uri.host;
  if (host.isEmpty) return invalidOptionalHttpUrl;
  if (host != 'localhost' && !host.contains('.')) {
    return invalidOptionalHttpUrl;
  }
  return null;
}
