import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lanonna/l10n/app_localizations.dart';

import 'api_exception.dart';
import 'localized_failure.dart';

/// Localized user copy for any failure surfaced from a repository call.
String apiErrorMessage(AppLocalizations l10n, Object error) {
  if (error is ApiException) {
    switch (error.errorCode) {
      case 'user_deleted':
        return l10n.errorAccountDeleted;
      case 'network_unavailable':
        return l10n.errorOffline;
      case 'network_timeout':
        return l10n.errorNetwork;
    }
    return error.serverMessage ?? l10n.errorGeneric;
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
