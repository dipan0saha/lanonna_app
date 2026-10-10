import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_error_message.dart';
import 'package:lanonna/core/api/api_exception.dart';

void main() {
  test('apiErrorMessage maps ApiException network codes', () {
    final msg = apiErrorMessage(
      ApiException('network_unavailable', detail: {'error': 'network_unavailable'}),
    );
    expect(msg, contains('offline'));
    expect(msg, isNot(contains('SocketException')));
  });

  test('apiErrorMessage maps SocketException', () {
    expect(
      apiErrorMessage(const SocketException('failed')),
      contains('offline'),
    );
  });
}
