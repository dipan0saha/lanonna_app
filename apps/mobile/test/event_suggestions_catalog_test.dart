import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/calendar/data/event_suggestions_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = const StringCodec().decodeMessage(message);
      if (key == 'assets/calendar/event_suggestions.json') {
        return const StringCodec().encodeMessage('''
{
  "expecting": [
    {"id": "baby_shower", "title": "Baby shower", "description": ""}
  ]
}
''');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('titleForId returns catalog title', () async {
    expect(
      await EventSuggestionsCatalog.titleForId('baby_shower'),
      'Baby shower',
    );
    expect(await EventSuggestionsCatalog.titleForId('missing'), isNull);
  });
}
