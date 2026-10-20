// ignore_for_file: avoid_print

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Flags prose string literals anywhere under lib/ (outside lib/l10n/).
///
/// The check is sink-agnostic: user copy reaches the screen through widget
/// arguments, return values, ternaries, switch arms, exceptions surfaced as
/// messages, etc., so every literal that reads as prose is a violation unless
/// it sits in a context that is structurally never shown to users (directives,
/// annotations, map/index keys, comparisons and case patterns, logging, keys,
/// URIs, regexes, programmer-error and diagnostic throws, `toString()`).
///
/// A literal "reads as prose" when its literal text (interpolations dropped)
/// contains a letter and either whitespace between words or starts with an
/// uppercase letter. Lowercase single tokens (`'pending'`, `'image/jpeg'`,
/// `'yyyy-MM-dd'`) are API/format identifiers and are ignored.
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
    if (_isGenerated(rel)) continue;

    final parseResult = parseFile(
      path: entity.path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    parseResult.unit.accept(
      _UserStringVisitor(rel, allowlist, violations, parseResult.lineInfo),
    );
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

/// Tool-generated sources (build_runner, FlutterFire) are not hand-written copy.
bool _isGenerated(String rel) =>
    rel.endsWith('.g.dart') ||
    rel.endsWith('.freezed.dart') ||
    rel == 'lib/firebase_options.dart' ||
    rel == 'lib/firebase/firebase_options_dev.dart';

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
final _wordSpaceWord = RegExp(r'\p{L}[^\n]*\s+[^\s]*\p{L}', unicode: true);
final _leadingUpper = RegExp(r'^\s*\p{Lu}', unicode: true);

/// The literal text a string expression contributes, taken from the AST (not
/// by pattern-matching `$`). Interpolated expressions become [slot], so
/// `'$count going'` reads as `X going` (prose) while `'$a · $b'` has no
/// letters of its own and is ignored.
String? _literalText(StringLiteral node, {String slot = ''}) {
  if (node is SimpleStringLiteral) return node.value;
  if (node is StringInterpolation) {
    return node.elements
        .map((e) => e is InterpolationString ? e.value : slot)
        .join();
  }
  if (node is AdjacentStrings) {
    final parts = node.strings.map((s) => _literalText(s, slot: slot));
    if (parts.any((p) => p == null)) return null;
    return parts.join();
  }
  return null;
}

final _allCapsToken = RegExp(r'^[A-Z0-9_-]+$');

bool _readsAsProse(StringLiteral node) {
  final text = _literalText(node);
  if (text == null || !_letter.hasMatch(text)) return false;
  final shaped = _literalText(node, slot: 'X')!.trim();
  // Route/API paths and URLs are identifiers, not copy.
  if (shaped.startsWith('/') || shaped.contains('://')) return false;
  // HTTP verbs, env names, constants.
  if (_allCapsToken.hasMatch(text.trim())) return false;
  return _wordSpaceWord.hasMatch(shaped) || _leadingUpper.hasMatch(text);
}

/// Callees whose string arguments are never rendered to users.
const _nonUserCallees = {
  'Uri', 'parse', 'tryParse', 'RegExp', 'Key', 'ValueKey', 'ObjectKey',
  'PageStorageKey', 'GlobalObjectKey', 'debugPrint', 'print', 'log',
  'DateFormat', 'StateError', 'ArgumentError', 'UnimplementedError',
  'UnsupportedError', 'AssertionError', 'FlutterError', 'MethodChannel',
  'EventChannel', 'recordError', 'Symbol', 'fromEnvironment',
  // Diagnostic-only exceptions: user copy comes from apiErrorMessage /
  // LocalizedFailure, never from these messages.
  'FormatException', 'ApiException',
};

class _UserStringVisitor extends RecursiveAstVisitor<void> {
  _UserStringVisitor(this.relPath, this.allowlist, this.violations,
      this.lineInfo);

  final String relPath;
  final Set<(String, String)> allowlist;
  final Set<String> violations;
  final LineInfo lineInfo;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) => _check(node);

  @override
  void visitStringInterpolation(StringInterpolation node) {
    _check(node);
    super.visitStringInterpolation(node); // nested literals in ${...}
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) => _check(node);

  void _check(StringLiteral node) {
    if (node.parent is AdjacentStrings) return; // reported as a whole
    if (!_readsAsProse(node)) return;
    if (_inNonUserContext(node)) return;
    final value = node is SimpleStringLiteral ? node.value : node.toSource();
    if (allowlist.contains((relPath, value))) return;
    final line = lineInfo.getLocation(node.offset).lineNumber;
    violations.add('$relPath:$line: ${node.toSource()}');
  }

  bool _inNonUserContext(AstNode literal) {
    // toString() is a debugging representation, never rendered as copy.
    final method = literal.thisOrAncestorOfType<MethodDeclaration>();
    if (method != null && method.name.lexeme == 'toString') return true;
    AstNode child = literal;
    for (var p = literal.parent; p != null; child = p, p = p.parent) {
      if (p is Directive || p is Annotation) return true;
      if (p is IndexExpression && identical(p.index, child)) return true;
      if (p is MapLiteralEntry && identical(p.key, child)) return true;
      if (p is CaseClause || p is SwitchPatternCase || p is ConstantPattern) {
        return true;
      }
      if (p is BinaryExpression) {
        final op = p.operator.lexeme;
        if (op == '==' || op == '!=') return true;
      }
      if (p is AssertStatement || p is AssertInitializer) return true;
      if (p is MethodInvocation &&
          identical(p.argumentList, child) &&
          (_nonUserCallees.contains(p.methodName.name) ||
              _isStringIdentityCall(p.methodName.name))) {
        return true;
      }
      if (p is InstanceCreationExpression &&
          identical(p.argumentList, child)) {
        final ctor = p.constructorName;
        if (_nonUserCallees.contains(ctor.type.name2.lexeme) ||
            _nonUserCallees.contains(ctor.name?.name)) {
          return true;
        }
      }
      // Stop climbing at statement / declaration boundaries.
      if (p is Statement || p is Declaration) return false;
    }
    return false;
  }

  static bool _isStringIdentityCall(String name) => const {
        'startsWith', 'endsWith', 'contains', 'replaceAll', 'replaceFirst',
        'split', 'indexOf',
      }.contains(name);
}
