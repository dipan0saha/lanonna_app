import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Blocks inherited-widget lookups inside [State.dispose] (see #436).
void main() {
  test('lib does not use context.read/of inside dispose()', () {
    final lib = Directory('lib');
    final violations = <String>[];
    final forbidden = RegExp(
      r'context\.(read|watch|select)\s*<|'
      r'Provider\.of\s*\(|'
      r'AppLocalizations\.of\s*\(\s*context\s*\)|'
      r'ScaffoldMessenger\.(maybeOf|of)\s*\(\s*context\s*\)',
    );

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = _stripComments(entity.readAsStringSync());
      final disposeBody = _extractDisposeBodies(source);
      for (final body in disposeBody) {
        if (forbidden.hasMatch(body)) {
          violations.add(entity.path);
          break;
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Do not look up inherited widgets in dispose(); persist on change or '
          'navigation instead: ${violations.join(', ')}',
    );
  });
}

List<String> _extractDisposeBodies(String source) {
  final bodies = <String>[];
  final startPattern = RegExp(r'void\s+dispose\s*\(\s*\)\s*\{');
  for (final match in startPattern.allMatches(source)) {
    final openBrace = match.end - 1;
    var depth = 0;
    var i = openBrace;
    for (; i < source.length; i++) {
      final ch = source[i];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          bodies.add(source.substring(openBrace + 1, i));
          break;
        }
      }
    }
  }
  return bodies;
}

String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks
      .split('\n')
      .map((line) {
        final slash = line.indexOf('//');
        return slash < 0 ? line : line.substring(0, slash);
      })
      .join('\n');
}
