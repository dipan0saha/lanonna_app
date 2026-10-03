import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/network/connectivity_service.dart';

void main() {
  test('internetStatusFromResults treats none-only as offline', () {
    expect(
      internetStatusFromResults([ConnectivityResult.none]),
      isFalse,
    );
  });

  test('internetStatusFromResults treats wifi as online', () {
    expect(
      internetStatusFromResults([ConnectivityResult.wifi]),
      isTrue,
    );
  });

  test('internetStatusFromResults treats empty as online', () {
    expect(internetStatusFromResults([]), isTrue);
  });
}
