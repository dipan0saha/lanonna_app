import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lanonna/core/api/api_error_message.dart';
import 'package:lanonna/core/api/api_exception.dart';

void main() {
  test('apiErrorMessage hides ClientException host details', () {
    final msg = apiErrorMessage(
      http.ClientException('Connection failed', Uri.parse('https://api.example.com/v1/x')),
    );
    expect(msg, contains("Couldn't reach"));
    expect(msg, isNot(contains('api.example.com')));
  });

  test('apiErrorMessage maps user_deleted', () {
    final msg = apiErrorMessage(
      ApiException('user_deleted', statusCode: 401, detail: {'error': 'user_deleted'}),
    );
    expect(msg, contains('deleted'));
  });

  test('apiErrorMessage maps SocketException to offline copy', () {
    expect(
      apiErrorMessage(SocketException('failed')),
      contains('offline'),
    );
  });
}
