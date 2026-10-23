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
    expect(uri.toString(), 'mailto:support@example.com?subject=La%20Nonna%20support');
  });

  test('buildMailtoUri encodes reserved characters in the subject', () {
    final uri = buildMailtoUri(
      address: 'support@example.com',
      subject: 'Help & support?',
    );
    expect(uri.query, 'subject=Help%20%26%20support%3F');
  });

  test('buildMailtoUri omits the query without a subject', () {
    expect(
      buildMailtoUri(address: 'help@example.com').toString(),
      'mailto:help@example.com',
    );
    expect(
      buildMailtoUri(address: 'help@example.com', subject: '').toString(),
      'mailto:help@example.com',
    );
  });
}
