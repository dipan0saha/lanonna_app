import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/account/domain/inbox_notification_kind.dart';
import 'package:lanonna/features/account/presentation/widgets/inbox_sentence.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

final _l10n = AppLocalizationsEn();

String _text(
  InboxNotificationKind? kind, {
  Map<String, String> params = const {},
  String? actor = 'Sue',
  String title = '',
  String body = '',
}) =>
    inboxSentence(
      _l10n,
      InboxNotification(
        id: 'n',
        kind: kind,
        params: params,
        actorDisplayName: actor,
        title: title,
        body: body,
      ),
    ).plainText;

void main() {
  test('RSVP rows read as sentences for every status', () {
    const shower = {'event_title': 'Shower'};
    expect(
      _text(InboxNotificationKind.eventRsvp, params: {...shower, 'rsvp_status': 'going'}),
      'Sue is going to "Shower"',
    );
    expect(
      _text(InboxNotificationKind.eventRsvp, params: {...shower, 'rsvp_status': 'maybe'}),
      'Sue might go to "Shower"',
    );
    expect(
      _text(InboxNotificationKind.eventRsvp, params: {...shower, 'rsvp_status': 'cant_go'}),
      'Sue can\'t make it to "Shower"',
    );
    expect(
      _text(InboxNotificationKind.eventRsvp, params: shower),
      'Sue replied to "Shower"',
    );
  });

  test('kinds render from ARB with name fallbacks', () {
    expect(_text(InboxNotificationKind.photoSquished), 'Sue squished your photo');
    expect(
      _text(InboxNotificationKind.registryBuying, params: {'item_name': 'Crib'}),
      'Sue is buying "Crib"',
    );
    expect(
      _text(InboxNotificationKind.inviteAccepted, actor: null),
      'Family member joined your baby',
    );
    expect(
      _text(InboxNotificationKind.babyArrived, params: {'baby_name': 'Parker'}),
      'Parker has arrived! See the announcement.',
    );
  });

  test('rows without a kind show the stored push text', () {
    expect(_text(null, title: 'New RSVP', body: 'Sue replied'), 'Sue replied');
    expect(_text(null, title: 'New RSVP'), 'New RSVP');
    expect(_text(null), 'Notification');
    expect(
      _text(InboxNotificationKind.eventCreated, body: 'Sue added an event'),
      'Sue added an event',
    );
  });

  test('fromJson reads kind and string params', () {
    final n = InboxNotification.fromJson({
      'id': 'n1',
      'notification_kind': 'event_commented',
      'params': {'event_title': 'Shower', 'bogus': 3},
    });
    expect(n.kind, InboxNotificationKind.eventCommented);
    expect(n.params, {'event_title': 'Shower'});
  });
}
