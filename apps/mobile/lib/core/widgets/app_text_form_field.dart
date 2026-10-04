import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../input/app_text_input_kind.dart';
import '../theme/app_text_theme.dart';

/// Form field with app-wide capitalization policy and regular input weight.
class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    super.key,
    this.kind = AppTextInputKind.none,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled,
    this.onChanged,
    this.onFieldSubmitted,
    this.onEditingComplete,
    this.validator,
    this.autovalidateMode,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.inputFormatters,
  });

  final AppTextInputKind kind;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool obscureText;
  final bool readOnly;
  final bool? enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onEditingComplete;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final policyFormatters = AppTextInputPolicy.formatters(kind);
    final formatters = <TextInputFormatter>[
      if (policyFormatters != null) ...policyFormatters,
      if (inputFormatters != null) ...inputFormatters!,
    ];

    final theme = Theme.of(context);
    final fieldStyle = style ?? AppTextTheme.fieldInput(theme.textTheme);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      onEditingComplete: onEditingComplete,
      validator: validator,
      autovalidateMode: autovalidateMode,
      style: fieldStyle,
      textAlign: textAlign,
      autofocus: autofocus,
      textCapitalization: AppTextInputPolicy.capitalization(kind),
      inputFormatters: formatters.isEmpty ? null : formatters,
    );
  }
}
