import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/account/presentation/widgets/inbox_notification_visuals.dart';

void main() {
  test('maps gallery deep links to photo visual', () {
    final visual = inboxNotificationVisual(
      deepLink: '/gallery/photo/abc',
      title: 'New activity',
      body: 'Someone commented',
    );
    expect(visual.icon, Icons.photo_outlined);
  });

  test('extracts actor name from title when not generic', () {
    final actor = inboxNotificationActorName(
      title: 'Grandma Sue',
      body: 'squished the announcement',
    );
    expect(actor, 'Grandma Sue');
  });
}
