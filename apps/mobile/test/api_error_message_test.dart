import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lanonna/core/api/api_error_code.dart';
import 'package:lanonna/core/api/api_error_message.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/media/display_encode.dart';
import 'package:lanonna/features/invitations/presentation/invite_accept_messages.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('network failures map to localized offline / unreachable copy', () {
    expect(
      apiErrorMessage(
        l10n,
        ApiException('network_unavailable',
            detail: {'error': 'network_unavailable'}),
      ),
      l10n.errorOffline,
    );
    expect(apiErrorMessage(l10n, const SocketException('x')), l10n.errorOffline);
    final msg = apiErrorMessage(
      l10n,
      http.ClientException('failed', Uri.parse('https://api.example.com/v1/x')),
    );
    expect(msg, l10n.errorNetwork);
    expect(msg, isNot(contains('api.example.com')));
  });

  test('error codes map to copy, never the raw code', () {
    final msg = apiErrorMessage(
      l10n,
      ApiException('user_deleted',
          statusCode: 401, detail: {'error': 'user_deleted'}),
    );
    expect(msg, l10n.errorAccountDeleted);
    expect(msg, isNot(contains('user_deleted')));
    expect(
      apiErrorMessage(
        l10n,
        ApiException('fun_closed',
            statusCode: 409, detail: {'error': 'fun_closed'}),
      ),
      l10n.errorFunClosed,
    );
    expect(
      apiErrorMessage(
        l10n,
        ApiException('membership_ended', statusCode: 403, detail: {
          'error': 'membership_ended',
          'message': 'You no longer have access to this baby profile.',
        }),
      ),
      l10n.membershipEndedMessage,
    );
  });

  test('server English is never shown; unknown codes fall back by status', () {
    expect(
      apiErrorMessage(
        l10n,
        ApiException('some_new_code', statusCode: 404, detail: {
          'error': 'some_new_code',
          'message': 'Server English',
        }),
      ),
      l10n.errorNotFound,
    );
    expect(
      apiErrorMessage(l10n, ApiException('http_400', statusCode: 400)),
      l10n.errorInvalidRequest,
    );
    expect(
      apiErrorMessage(l10n, ApiException('http_500', statusCode: 500)),
      l10n.errorGeneric,
    );
    expect(apiErrorMessage(l10n, StateError('boom')), l10n.errorGeneric);
  });

  test('params fill parameterized copy', () {
    expect(
      apiErrorMessage(
        l10n,
        ApiException('text_too_long', statusCode: 400, detail: {
          'error': 'text_too_long',
          'params': {'max_length': 80},
        }),
      ),
      l10n.errorTextTooLong(80),
    );
    expect(
      apiErrorMessage(
        l10n,
        ApiException('text_too_long',
            statusCode: 400, detail: {'error': 'text_too_long'}),
      ),
      l10n.errorInvalidRequest,
    );
  });

  test('every code has its own non-empty copy', () {
    for (final code in ApiErrorCode.values) {
      expect(code.userMessage(l10n), isNotEmpty, reason: code.apiValue);
      expect(ApiErrorCode.fromApi(code.apiValue), code);
    }
  });

  test('localized failures supply their own copy', () {
    expect(
      apiErrorMessage(l10n, const PhotoTooLargeException(displayMaxBytes)),
      l10n.errorPhotoTooLarge('2'),
    );
    expect(
      apiErrorMessage(l10n, const InviteAcceptException('max_owners')),
      l10n.inviteErrorMaxOwners,
    );
  });

  test('photo source hint follows displayMaxBytes', () {
    expect(displayPhotoSourceHint(l10n), 'JPEG or PNG, up to 2MB');
    expect(megabytesLabel(1572864), '1.5');
  });
}
