// ignore_for_file: avoid_print

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Flags string literals that flow into user-facing widget parameters under lib/.
void main(List<String> args) {
  final root = args.isNotEmpty ? args.first : '.';
  final libDir = Directory('$root/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('Missing lib/ under $root');
    exit(2);
  }

  final allowlist = _loadAllowlist(
    '$root/tool/hardcoded_user_strings_allowlist.txt',
  );
  final violations = <String>{};

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = _relativePath(root, entity.path);
    if (rel.startsWith('lib/l10n/')) continue;

    final parseResult = parseFile(
      path: entity.path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    final lineInfo = parseResult.lineInfo;
    final unit = parseResult.unit;
    unit.accept(_UserStringVisitor(rel, allowlist, violations, lineInfo));
  }

  final sorted = violations.toList()..sort();
  if (sorted.isNotEmpty) {
    print(
      'Hardcoded user-facing string literals (move to lib/l10n/app_en.arb):',
    );
    for (final v in sorted) {
      print('  $v');
    }
    exit(1);
  }
  print('OK: no hardcoded user-facing string literals.');
}

Set<(String, String)> _loadAllowlist(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final allow = <(String, String)>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('|');
    if (parts.length != 3 || parts[2].trim().isEmpty) {
      stderr.writeln('Allowlist entry needs path|literal|justification: $raw');
      exit(2);
    }
    allow.add((parts[0].trim(), parts[1]));
  }
  return allow;
}

String _relativePath(String root, String filePath) {
  final normalizedRoot = root.endsWith('/') ? root : '$root/';
  if (filePath.startsWith(normalizedRoot)) {
    return filePath.substring(normalizedRoot.length);
  }
  return filePath;
}

final _letter = RegExp(r'\p{L}', unicode: true);

/// The literal text a string expression contributes, with interpolated
/// expressions dropped (taken from the AST, not by pattern-matching `$`).
String? _literalText(Expression node) {
  if (node is SimpleStringLiteral) return node.value;
  if (node is StringInterpolation) {
    return node.elements
        .whereType<InterpolationString>()
        .map((e) => e.value)
        .join();
  }
  if (node is AdjacentStrings) {
    final parts = node.strings.map(_literalText);
    if (parts.any((p) => p == null)) return null;
    return parts.join();
  }
  return null;
}

class _UserStringVisitor extends RecursiveAstVisitor<void> {
  _UserStringVisitor(
    this.relPath,
    this.allowlist,
    this.violations,
    this.lineInfo,
  );

  final String relPath;
  final Set<(String, String)> allowlist;
  final Set<String> violations;
  final LineInfo lineInfo;

  static const _namedParamLabels = {
    'label',
    'hintText',
    'labelText',
    'tooltip',
    'semanticsLabel',
    'title',
    'message',
    'helperText',
    'errorText',
    'content',
    'actionLabel',
    'prefix',
    'hint',
    'text',
    'emptyMessage',
    'saveLabel',
    'buttonLabel',
    'placeholder',
    'confirmLabel',
    'cancelLabel',
  };

  void _checkLiteral(Expression node, {String? namedParam}) {
    final text = _literalText(node);
    if (text == null || !_letter.hasMatch(text)) return;
    final lexeme = node.toSource();
    final value = node is SimpleStringLiteral ? node.value : lexeme;
    if (allowlist.contains((relPath, value))) return;
    final line = lineInfo.getLocation(node.offset).lineNumber;
    final context = namedParam != null ? ' ($namedParam)' : '';
    violations.add('$relPath:$line:$context $lexeme');
  }

  void _visitArgumentList(ArgumentList args, {String? callee}) {
    if (callee == 'Text') {
      final positional = args.arguments;
      if (positional.isNotEmpty && positional.first is! NamedExpression) {
        final first = positional.first;
        if (first is StringLiteral) _checkLiteral(first);
      }
    }
    if (callee == 'TextSpan') {
      for (final arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'text') {
          final expr = arg.expression;
          if (expr is StringLiteral) {
            _checkLiteral(expr, namedParam: 'text');
          }
        }
      }
    }
    for (final arg in args.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if (_namedParamLabels.contains(name)) {
          final expr = arg.expression;
          if (expr is StringLiteral) {
            _checkLiteral(expr, namedParam: name);
          }
        }
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    _visitArgumentList(node.argumentList, callee: typeName);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Unresolved widget constructors are parsed as method invocations.
    _visitArgumentList(node.argumentList, callee: node.methodName.name);
    super.visitMethodInvocation(node);
  }

  @override
  void visitDefaultFormalParameter(DefaultFormalParameter node) {
    final name = node.parameter.name?.lexeme;
    if (name == null) {
      super.visitDefaultFormalParameter(node);
      return;
    }
    if (_namedParamLabels.contains(name)) {
      final defaultValue = node.defaultValue;
      if (defaultValue is StringLiteral) {
        _checkLiteral(defaultValue, namedParam: name);
      }
    }
    super.visitDefaultFormalParameter(node);
  }
}
