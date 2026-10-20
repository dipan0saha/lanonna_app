import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/config/prod_config_guard.dart';

void main() {
  test('detects __PROD_ placeholders', () {
    expect(isProdPlaceholderValue('__PROD_API_BASE_URL__'), isTrue);
    expect(isProdPlaceholderValue('https://api.example.com'), isFalse);
    expect(isProdPlaceholderValue(''), isTrue);
  });

  test('const guard placeholders match every __PROD_ value in prod.json', () {
    final prod =
        jsonDecode(File('flavors/prod.json').readAsStringSync())
            as Map<String, dynamic>;
    final placeholders = prod.values
        .whereType<String>()
        .where((v) => v.startsWith(prodConfigPlaceholderPrefix))
        .toSet();
    expect(placeholders, {
      prodApiBaseUrlPlaceholder,
      prodAppLinkHostPlaceholder,
      prodGoogleSignInClientIdPlaceholder,
    });
    expect(prod['API_BASE_URL'], prodApiBaseUrlPlaceholder);
    expect(prod['APP_LINK_HOST'], prodAppLinkHostPlaceholder);
    expect(
      prod['GOOGLE_SIGN_IN_SERVER_CLIENT_ID'],
      prodGoogleSignInClientIdPlaceholder,
    );
  });
}
