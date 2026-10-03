import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';

void main() {
  test('NotificationPreferences.fromJson reads channel flags', () {
    final prefs = NotificationPreferences.fromJson({
      'notification_digest': 'daily',
      'push_notifications_enabled': true,
      'email_digest_enabled': false,
      'notify_gallery_enabled': false,
      'notify_calendar_enabled': true,
      'notify_registry_enabled': true,
      'notify_comments_enabled': false,
    });
    expect(prefs.digest, 'daily');
    expect(prefs.notifyGalleryEnabled, isFalse);
    expect(prefs.notifyCommentsEnabled, isFalse);
  });
}
