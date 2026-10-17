import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lanonna/l10n/app_localizations.dart';

import 'api_error_code.dart';
import 'api_exception.dart';
import 'localized_failure.dart';

/// Localized user copy for any failure surfaced from a repository call.
///
/// API errors resolve through their [ApiErrorCode] (or the status category
/// when the code is unknown to this build); server text is never shown.
String apiErrorMessage(AppLocalizations l10n, Object error) {
  if (error is ApiException) {
    final code = error.code ?? ApiErrorCode.forStatus(error.statusCode);
    return code.userMessage(l10n, error.params);
  }
  if (error is LocalizedFailure) return error.userMessage(l10n);
  if (error is SocketException) return l10n.errorOffline;
  if (error is TimeoutException ||
      error is http.ClientException ||
      error is HandshakeException) {
    return l10n.errorNetwork;
  }
  return l10n.errorGeneric;
}
