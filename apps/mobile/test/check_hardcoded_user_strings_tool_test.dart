@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs tool/check_hardcoded_user_strings.dart against a scratch project so the
/// guard itself is proven to fail on violations (and pass on clean code).
Future<ProcessResult> _runGuard(Map<String, String> libFiles) async {
  final root = await Directory.systemTemp.createTemp('l10n_guard_');
  addTearDown(() => root.delete(recursive: true));
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
}
