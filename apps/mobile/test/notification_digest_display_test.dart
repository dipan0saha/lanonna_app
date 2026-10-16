import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/account/domain/notification_digest_display.dart';

void main() {
  test('notificationDigestSummaryLabel maps digest values', () {
    expect(notificationDigestSummaryLabel('weekly'), 'Weekly email summary');
    expect(notificationDigestSummaryLabel('daily'), 'Daily email summary');
    expect(notificationDigestSummaryLabel('realtime'), 'Real-time updates');
    expect(notificationDigestSummaryLabel('unknown'), 'Real-time updates');
  });
}
