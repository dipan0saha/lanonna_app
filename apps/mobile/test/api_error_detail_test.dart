import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';

void main() {
  test('formatApiErrorDetail returns string detail', () {
    expect(formatApiErrorDetail('Date of birth cannot be in the future.'), contains('future'));
  });

  test('formatApiErrorDetail joins validation list messages', () {
    final detail = [
      {'type': 'missing', 'loc': ['body', 'name'], 'msg': 'Field required'},
      {'type': 'string_too_short', 'loc': ['body', 'title'], 'msg': 'Too short'},
    ];
    expect(formatApiErrorDetail(detail), 'Field required; Too short');
  });
}
