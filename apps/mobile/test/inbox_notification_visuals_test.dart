import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/account/domain/inbox_notification_type.dart';
import 'package:lanonna/features/account/presentation/widgets/inbox_notification_visuals.dart';

void main() {
  test('maps API notification type to photo visual', () {
    final visual = inboxNotificationVisualForType(InboxNotificationType.photo);
    expect(visual.icon, Icons.photo_outlined);
  });

  test('unknown API type maps to generic visual', () {
    final visual = inboxNotificationVisualForType(
      InboxNotificationType.generic,
    );
    expect(visual.icon, Icons.notifications_outlined);
  });
}
