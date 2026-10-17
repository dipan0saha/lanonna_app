@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs tool/check_hardcoded_user_strings.dart against a scratch project so the
/// guard itself is proven to fail on violations (and pass on clean code).
Future<ProcessResult> _runGuard(
  Map<String, String> libFiles, {
  String? allowlist,
}) async {
  final root = await Directory.systemTemp.createTemp('l10n_guard_');
  addTearDown(() => root.delete(recursive: true));
  if (allowlist != null) {
    final file = File('${root.path}/tool/hardcoded_user_strings_allowlist.txt');
    await file.create(recursive: true);
    await file.writeAsString(allowlist);
  }
  for (final entry in libFiles.entries) {
    final file = File('${root.path}/lib/${entry.key}');
    await file.create(recursive: true);
    await file.writeAsString(entry.value);
  }
  return Process.run(
    Platform.resolvedExecutable.contains('flutter_tester')
        ? 'dart'
        : Platform.resolvedExecutable,
    ['run', 'tool/check_hardcoded_user_strings.dart', root.path],
  );
}

void main() {
  test(
    'fails on plain, interpolated, adjacent and named-param literals',
    () async {
      final result = await _runGuard({
        'bad.dart': r'''
Object a(String name) => [
  Text('Plain copy'),
  Text('Hello $name'),
  Text('Adjacent ' 'strings'),
  InputDecoration(hintText: 'Type ${name.length} here'),
];
''',
      });
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      for (final line in [':2:', ':3:', ':4:', ':5:']) {
        expect(out, contains('lib/bad.dart$line'));
      }
    },
  );

  test('passes on symbol-only and localized text', () async {
    final result = await _runGuard({
      'ok.dart': r'''
Object a(String name, dynamic l10n) => [
  Text('🎉'),
  Text('$name'),
  Text('• ${name.length}'),
  Text(l10n.title),
];
''',
    });
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('fails on copy in any sink, not only widget arguments', () async {
    final result = await _runGuard({
      'sinks.dart': r'''
String a(bool ok) {
  return 'Returned copy';
}
String b(bool ok) => ok ? 'Ternary yes' : 'no';
String c(int n) => switch (n) { 0 => 'Switch arm copy', _ => '' };
void d({String label = 'Default parameter'}) {}
final e = Exception('Shown to the user');
String f(String name) => 'Prefix ${name.isEmpty ? 'Nested copy' : name}';
final g = <String>['List element copy'];
''',
    });
    expect(result.exitCode, 1);
    final out = result.stdout as String;
    for (final literal in [
      'Returned copy',
      'Ternary yes',
      'Switch arm copy',
      'Default parameter',
      'Shown to the user',
      'Nested copy',
      'List element copy',
    ]) {
      expect(out, contains(literal));
    }
  });

  test('ignores contexts that are never shown to users', () async {
    final result = await _runGuard({
      'ok_contexts.dart': r'''
import 'package:flutter/material.dart';
@Deprecated('Use something else')
Object a(Map<String, Object> json, String s, String code) {
  debugPrint('Debug only text');
  assert(s.isNotEmpty, 'Programmer message');
  if (code == 'Some Value') {}
  switch (code) {
    case 'Case Label':
      break;
  }
  if (s.startsWith('Prefix Text')) {}
  return [
    json['Map Key'],
    {'Literal Key': 1},
    Uri.parse('Not A Url'),
    RegExp('Hello world'),
    const ValueKey('Widget Key'),
    StateError('Bad state here'),
    FormatException('Bad format here'),
    'pending',
    'image/jpeg',
    'API_BASE_URL',
    '/route/path',
    'https://example.com/Path',
  ];
}
class P {
  @override
  String toString() => 'P debug text';
}
''',
      'firebase_options.dart': "const k = 'Generated Value';",
    });
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('allowlist exempts a justified literal and rejects a bare one', () async {
    const files = {'brand.dart': "const font = 'Dancing Script';"};
    final allowed = await _runGuard(
      files,
      allowlist: 'lib/brand.dart|Dancing Script|Font family name.\n',
    );
    expect(allowed.exitCode, 0, reason: '${allowed.stdout}${allowed.stderr}');

    final unjustified = await _runGuard(
      files,
      allowlist: 'lib/brand.dart|Dancing Script|\n',
    );
    expect(unjustified.exitCode, 2);
  });
}
