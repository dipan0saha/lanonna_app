import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/activity_event_type.dart';
import 'package:lanonna/core/widgets/activity/activity_sentence.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

final _l10n = AppLocalizationsEn();

String _text(
  ActivityEventType? type, {
  Map<String, String> params = const {},
  String? actor = 'Sarah',
  String? target,
  String summary = 'stored',
}) =>
    activitySentence(
      _l10n,
      HomeActivityItem(
        id: 'x',
        eventType: type,
        params: params,
        summary: summary,
        createdAt: '',
        actorDisplayName: actor,
        targetDisplayName: target,
      ),
    ).plainText;

void main() {
  test('every known type renders from ARB', () {
    expect(_text(ActivityEventType.photoShared), 'Sarah shared a photo');
    expect(
      _text(ActivityEventType.photoSquish, params: {'caption': 'Nursery'}),
      'Sarah squished "Nursery"',
    );
    expect(
      _text(ActivityEventType.registryPurchased, params: {'item_name': 'Crib'}),
      'Sarah marked "Crib" as purchased',
    );
    expect(
      _text(ActivityEventType.registryClaimed, params: {'item_name': 'Crib'}),
      'Someone is buying "Crib"',
    );
    expect(
      _text(ActivityEventType.eventCreated, params: {'event_title': 'Shower'}),
      'Sarah added "Shower" to the calendar',
    );
    expect(
      _text(ActivityEventType.nameSuggested, params: {'suggested_name': 'Ivy'}),
      'Sarah suggested the name "Ivy"',
    );
    expect(
      _text(ActivityEventType.memberRemoved, target: 'Ann'),
      'Sarah removed Ann from the family',
    );
    expect(_text(ActivityEventType.memberLeft), 'Sarah left the family');
  });

  test('gender guesses are localized, never the raw API value', () {
    expect(
      _text(ActivityEventType.genderVoteCast, params: {'gender': 'female'}),
      'Sarah guessed girl',
    );
    expect(
      _text(ActivityEventType.genderVoteCast, params: {'gender': 'male'}),
      'Sarah guessed boy',
    );
    expect(_text(ActivityEventType.genderVoteCast), 'Sarah made a gender guess');
  });

  test('missing names use the app fallbacks', () {
    expect(_text(ActivityEventType.photoShared, actor: '  '), 'Family member shared a photo');
    expect(
      _text(ActivityEventType.babyArrived, params: {'baby_name': 'Parker'}),
      'Parker has arrived!',
    );
    expect(_text(ActivityEventType.babyArrived), 'Baby has arrived!');
  });

  test('unknown types and rows missing a required value show the summary', () {
    expect(_text(null, summary: 'From a newer server'), 'From a newer server');
    expect(
      _text(ActivityEventType.eventCreated, summary: 'Sarah added an event'),
      'Sarah added an event',
    );
  });
}
