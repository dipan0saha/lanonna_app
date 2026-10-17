import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/comments/comment_composer_controller.dart';
import 'package:lanonna/core/comments/comment_thread_port.dart';

class _RecordingPort implements CommentThreadPort {
  _RecordingPort({this.failAdd});

  final Object? failAdd;
  var adds = 0;
  String? lastText;

  @override
  Future<void> add(String text) async {
    adds += 1;
    lastText = text;
    final fail = failAdd;
    if (fail != null) throw fail;
  }

  @override
  Future<void> update(String commentId, String text) async {}

  @override
  Future<void> delete(String commentId) async {}
}

void main() {
  testWidgets('comment composer unfocus clears the field focus', (tester) async {
    final port = _RecordingPort();
    final composer = CommentComposerController(
      port: port,
      onPosted: () async {},
    );
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
home: Scaffold(
          body: TextField(
            focusNode: composer.focusNode,
            controller: composer.textController,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(composer.focusNode.hasFocus, isTrue);

    composer.unfocus();
    await tester.pump();

    expect(composer.focusNode.hasFocus, isFalse);
    composer.dispose();
  });

  test('blank comment does not call the port', () async {
    final port = _RecordingPort();
    final composer = CommentComposerController(
      port: port,
      onPosted: () async {},
    );
    composer.textController.text = '   ';
    await composer.submit();
    expect(port.adds, 0);
    composer.dispose();
  });

  test('successful comment clears text and reports posted', () async {
    final port = _RecordingPort();
    var posted = 0;
    final composer = CommentComposerController(
      port: port,
      onPosted: () async {
        posted += 1;
      },
    );
    composer.textController.text = 'hello family';
    await composer.submit();
    expect(port.adds, 1);
    expect(port.lastText, 'Hello family');
    expect(composer.textController.text, isEmpty);
    expect(posted, 1);
    expect(composer.sending, isFalse);
    composer.dispose();
  });

  test('failed comment keeps text and resets sending', () async {
    final port = _RecordingPort(failAdd: StateError('nope'));
    Object? reported;
    final composer = CommentComposerController(
      port: port,
      onPosted: () async {},
      onError: (error) => reported = error,
    );
    composer.textController.text = 'keep me';
    await composer.submit();
    expect(composer.textController.text, 'keep me');
    expect(reported, isA<StateError>());
    expect(composer.sending, isFalse);
    composer.dispose();
  });

  test('overlapping submit sends once', () async {
    final port = _SlowPort();
    final composer = CommentComposerController(
      port: port,
      onPosted: () async {},
    );
    composer.textController.text = 'once';
    final first = composer.submit();
    final second = composer.submit();
    await Future.wait([first, second]);
    expect(port.adds, 1);
    composer.dispose();
  });
}

class _SlowPort implements CommentThreadPort {
  var adds = 0;

  @override
  Future<void> add(String text) async {
    adds += 1;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<void> update(String commentId, String text) async {}

  @override
  Future<void> delete(String commentId) async {}
}
