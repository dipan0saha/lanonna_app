import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/platform/mailto_uri.dart';

void main() {
  test('buildMailtoUri percent-encodes subject spaces for mail clients', () {
    final uri = buildMailtoUri(
      address: 'support@example.com',
      subject: 'La Nonna support',
    );
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'support@example.com');
    expect(uri.query, 'subject=La%20Nonna%20support');
    expect(uri.toString(), isNot(contains('+')));
  });

  test('buildMailtoUri omits query when subject and body are empty', () {
    final uri = buildMailtoUri(address: 'help@example.com');
    expect(uri.query, isNull);
  });

  test('buildMailtoUri encodes subject and body', () {
    final uri = buildMailtoUri(
      address: 'help@example.com',
      subject: 'Hello',
      body: 'Line one\nLine two',
    );
    expect(uri.query, contains('subject=Hello'));
    expect(uri.query, contains('body=Line%20one%0ALine%20two'));
  });
}
