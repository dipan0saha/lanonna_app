import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../input/app_text_input_kind.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'app_semantics.dart';
import 'app_text_field.dart';

/// In-app text field with label above the box (prototype / PRD §5.1).
///
/// Uses [hintText] inside the field instead of Material floating labels so
/// filled edit forms stay readable and evenly spaced.
class AppLabeledTextField extends StatelessWidget {
  const AppLabeledTextField({
    super.key,
    required this.label,
    this.hint,
    this.semanticsId,
    this.kind = AppTextInputKind.none,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.inputFormatters,
    this.spacingAfter = AppMetrics.formFieldSpacing,
  });

  final String label;
  final String? hint;
  final String? semanticsId;
  final AppTextInputKind kind;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool obscureText;
  final bool readOnly;
  final bool? enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final double spacingAfter;

  @override
  Widget build(BuildContext context) {
    final field = AppTextField(
      kind: kind,
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(hintText: hint),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      style: style,
      textAlign: textAlign,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
    );

    final labeledField = semanticsId == null
        ? field
        : AppSemantics.textField(semanticsId!, field);

    return Padding(
      padding: EdgeInsets.only(bottom: spacingAfter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.fieldLabelStyle),
          const SizedBox(height: AppMetrics.fieldLabelGap),
          labeledField,
        ],
      ),
    );
  }
}
