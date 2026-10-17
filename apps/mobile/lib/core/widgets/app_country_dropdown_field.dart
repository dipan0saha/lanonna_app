import 'package:flutter/material.dart';

import '../data/iso_countries.dart';
import '../theme/app_colors.dart';
import '../theme/la_nonna_theme.dart';
import '../../l10n/app_localizations.dart';

/// ISO country picker with the same typography as [AppTextFormField] (not theme bodyLarge).
class AppCountryDropdownField extends StatelessWidget {
  AppCountryDropdownField({
    super.key,
    required this.countries,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.enabled = true,
    this.decoration,
    this.validator,
    this.autovalidateMode,
  });

  final List<IsoCountry> countries;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? hintText;
  final bool enabled;
  final InputDecoration? decoration;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fieldStyle = context.fieldInputStyle;
    final hintStyle = context.textStyles.bodyMedium?.copyWith(
      color: AppColors.muted,
    );

    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      style: fieldStyle,
      hint: Text(hintText ?? l10n.fieldSelectCountry, style: hintStyle),
      decoration: decoration ?? const InputDecoration(),
      validator: validator,
      autovalidateMode: autovalidateMode,
      items: [
        for (final c in countries)
          DropdownMenuItem(
            value: c.code,
            child: Text(
              c.name,
              style: fieldStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
