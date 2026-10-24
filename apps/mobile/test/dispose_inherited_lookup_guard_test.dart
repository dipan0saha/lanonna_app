import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Blocks inherited-widget and ancestor lookups inside `dispose()` (#436).
///
/// During tree teardown the providers and other ancestors may already be
/// gone, so `context.read`, `X.of(context)` and friends throw there. Persist
/// on change or navigation instead.
void main() {
  test('lib does not look up inherited widgets inside dispose()', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final lookup in disposeLookups(entity.readAsStringSync())) {
        violations.add('${entity.path}: $lookup');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Do not look up inherited widgets in dispose(); persist on change or '
          'navigation instead:\n${violations.join('\n')}',
    );
  });

  group('disposeLookups', () {
    String state(String disposeBody, {String other = ''}) =>
        '''
class _S extends State<W> {
  $other
  @override
  void dispose() {
    $disposeBody
    super.dispose();
  }
}
''';

    for (final call in [
      'context.read<Foo>().save();',
      'context.read().save();',
      'context.watch<Foo>();',
      'context.select<Foo, int>((f) => f.n);',
      'Provider.of<Foo>(context, listen: false).save();',
      'AppLocalizations.of(context)!.title;',
      'ScaffoldMessenger.maybeOf(context)?.clearSnackBars();',
      'Theme.of(context);',
      'MediaQuery.maybeOf(this.context);',
      'context.dependOnInheritedWidgetOfExactType<Foo>();',
      'context.findAncestorStateOfType<FooState>();',
      'if (x) { context.read<Foo>().save(); }',
    ]) {
      test('flags $call', () {
        expect(disposeLookups(state(call)), hasLength(1));
      });
    }

    for (final (name, source) in [
      (
        'lookup outside dispose',
        state(
          '_c.dispose();',
          other: 'void save() { context.read<Foo>().save(); }',
        ),
      ),
      (
        'lookup in a comment',
        state(
          '// context.read<Foo>().save();\n'
          '/* Theme.of(context) */ _c.dispose();',
        ),
      ),
      ('lookup in a string', state("debugPrint('context.read<Foo>() {');")),
      ('URL in a string', state("_log('https://x/{'); _c.dispose();")),
      ('controller dispose', state('_c.dispose(); _sub?.cancel();')),
      ('mounted check', state('if (context.mounted) _c.dispose();')),
    ]) {
      test('ignores $name', () {
        expect(disposeLookups(source), isEmpty);
      });
    }

    test('flags a lookup reached through a private helper (#436)', () {
      final source = state(
        '_persist();',
        other:
            'Future<void> _persist() async {\n'
            '  await context.read<Foo>().save(_draft());\n'
            '}\n'
            'Draft _draft() => Draft(Theme.of(context).x);',
      );
      expect(disposeLookups(source), [
        'context.read (via _persist)',
        'Theme.of(context (via _draft)',
      ]);
    });

    test('ignores private helpers that do no lookup', () {
      final source = state(
        '_stop();',
        other: 'void _stop() { _timer?.cancel(); _stop(); }',
      );
      expect(disposeLookups(source), isEmpty);
    });

    test('finds lookups in a second dispose in the same file', () {
      final source =
          '${state('_c.dispose();')}\n${state('Theme.of(context);')}';
      expect(disposeLookups(source), ['Theme.of(context']);
    });
  });
}

final _lookup = RegExp(
  r'\bcontext\s*\.\s*(read|watch|select)\b|'
  r'\b[A-Z]\w*\s*\.\s*(of|maybeOf)\s*(<[^>(]*>)?\s*\(\s*(this\s*\.\s*)?context\b|'
  r'\bcontext\s*\.\s*(dependOnInheritedWidgetOfExactType|'
  r'getInheritedWidgetOfExactType|getElementForInheritedWidgetOfExactType|'
  r'findAncestor\w*)\b',
);

final _disposeStart = RegExp(r'\bdispose\s*\(\s*\)\s*(async\s*)?\{');
final _privateName = RegExp(r'\b(_\w+)\s*\(');

/// Inherited lookups reachable from any `dispose() { ... }` in [source]:
/// directly, or through private methods of the same file it calls (the #436
/// crashes went through `_syncDraft()` and `_persistEmail()`).
List<String> disposeLookups(String source) {
  final code = _codeOnly(source);
  final methods = _privateMethodBodies(code);
  final found = <String>[];
  for (final match in _disposeStart.allMatches(code)) {
    final body = _block(code, match.end - 1);
    if (body == null) continue;
    final visited = <String>{};
    void scan(String text, String via) {
      for (final m in _lookup.allMatches(text)) {
        found.add('${m[0]}$via');
      }
      for (final call in _privateName.allMatches(text)) {
        final name = call[1]!;
        final callee = methods[name];
        if (callee == null || !visited.add(name)) continue;
        scan(callee, ' (via $name)');
      }
    }

    scan(body, '');
  }
  return found;
}

/// Bodies of private functions and methods declared in [code], by name.
Map<String, String> _privateMethodBodies(String code) {
  final bodies = <String, String>{};
  for (final m in _privateName.allMatches(code)) {
    final close = _matching(code, m.end - 1, '(', ')');
    if (close == null) continue;
    final rest = code.substring(close + 1);
    final head = RegExp(
      r'^\s*(async\s*\*?|sync\s*\*)?\s*(\{|=>)',
    ).firstMatch(rest);
    if (head == null) continue;
    final start = close + 1 + head.end - head[2]!.length;
    final body = head[2] == '{'
        ? _block(code, start)
        : code.substring(start, _expressionEnd(code, start));
    if (body != null) bodies[m[1]!] = body;
  }
  return bodies;
}

String? _block(String code, int openBrace) {
  final close = _matching(code, openBrace, '{', '}');
  return close == null ? null : code.substring(openBrace + 1, close);
}

int? _matching(String code, int open, String opening, String closing) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if (code[i] == opening) depth++;
    if (code[i] == closing && --depth == 0) return i;
  }
  return null;
}

int _expressionEnd(String code, int start) {
  var depth = 0;
  for (var i = start; i < code.length; i++) {
    final ch = code[i];
    if ('([{'.contains(ch)) depth++;
    if (')]}'.contains(ch)) depth--;
    if ((ch == ';' && depth == 0) || depth < 0) return i;
  }
  return code.length;
}

/// [source] with comments removed and string literal contents blanked, so
/// braces and lookups inside them are not counted.
String _codeOnly(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
    } else if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? source.length : end + 2;
    } else if (source[i] == "'" || source[i] == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final quote = source.startsWith(source[i] * 3, i)
          ? source[i] * 3
          : source[i];
      i += quote.length;
      while (i < source.length && !source.startsWith(quote, i)) {
        if (!raw && source[i] == r'\') i++;
        if (quote.length == 1 && source[i] == '\n') break;
        i++;
      }
      i += quote.length;
      out.write("''");
    } else {
      out.write(source[i]);
      i++;
    }
  }
  return out.toString();
}
