import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lanonna/core/api/api_error_message.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/api/display_photo_upload.dart';
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
      l10n.errorGeneric,
    );
  });

  test('server copy is shown; diagnostic messages are not', () {
    expect(
      apiErrorMessage(
        l10n,
        ApiException('http_400', statusCode: 400, serverMessage: 'Name taken'),
      ),
      'Name taken',
    );
    expect(
      apiErrorMessage(l10n, ApiException('http_500', statusCode: 500)),
      l10n.errorGeneric,
    );
    expect(apiErrorMessage(l10n, StateError('boom')), l10n.errorGeneric);
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
