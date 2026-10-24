import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/relationship_preset.dart';

import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/l10n/placeholder_rich_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import 'onboarding_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Parent-driven [FormField] updates must not call [FormFieldState.didChange]
/// synchronously from [State.didUpdateWidget] while an ancestor [Form] is building.
void deferFormFieldDidChange(State state, VoidCallback apply) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted) return;
    apply();
  });
}

class OnboardingTextField extends StatelessWidget {
  const OnboardingTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.readOnly = false,
    this.onChanged,
    this.validator,
    this.onFieldSubmitted,
    this.textInputAction,
    this.fieldKey,
    this.semanticsId,
    this.kind = AppTextInputKind.none,
    this.autovalidateMode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final Key? fieldKey;
  final String? semanticsId;
  final AppTextInputKind kind;
  final AutovalidateMode? autovalidateMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          OnboardingFieldLabel(label!),
          const SizedBox(height: 8),
        ],
        _maybeSemanticsField(
          semanticsId: semanticsId,
          child: AppTextFormField(
            key: fieldKey,
            kind: kind,
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onChanged: onChanged,
            validator: validator,
            onFieldSubmitted: onFieldSubmitted,
            textInputAction: textInputAction,
            autovalidateMode: autovalidateMode,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      ],
    );
  }
}

/// Terms acceptance inside a [Form] (revalidates on user interaction).
class OnboardingTermsFormField extends StatefulWidget {
  const OnboardingTermsFormField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onTermsTap,
    required this.onPrivacyTap,
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final FormFieldValidator<bool>? validator;
  final AutovalidateMode autovalidateMode;
  final bool enabled;

  @override
  State<OnboardingTermsFormField> createState() =>
      _OnboardingTermsFormFieldState();
}

class _OnboardingTermsFormFieldState extends State<OnboardingTermsFormField> {
  final _fieldKey = GlobalKey<FormFieldState<bool>>();

  @override
  void didUpdateWidget(OnboardingTermsFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final field = _fieldKey.currentState;
    if (oldWidget.value != widget.value &&
        field != null &&
        !field.hasInteractedByUser) {
      final next = widget.value;
      deferFormFieldDidChange(this, () {
        if (!field.mounted || field.hasInteractedByUser) return;
        field.didChange(next);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      key: _fieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingTermsAgreementCheckbox(
              value: widget.value,
              onChanged: widget.enabled
                  ? (v) {
                      final accepted = v ?? false;
                      final hadError = field.hasError;
                      field.didChange(accepted);
                      widget.onChanged(accepted);
                      if (hadError) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          field.validate();
                        });
                      }
                    }
                  : null,
              onTermsTap: widget.onTermsTap,
              onPrivacyTap: widget.onPrivacyTap,
            ),
            if (field.hasError) ...[
              const SizedBox(height: 4),
              Text(
                field.errorText!,
                style: TextStyle(
                  color: Theme.of(field.context).colorScheme.error,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Mother/Father pill select inside a [Form].
class OnboardingRelationshipFormField extends StatefulWidget {
  const OnboardingRelationshipFormField({
    super.key,
    required this.value,
    required this.onSelected,
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  final String? value;
  final ValueChanged<String> onSelected;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;

  @override
  State<OnboardingRelationshipFormField> createState() =>
      _OnboardingRelationshipFormFieldState();
}

class _OnboardingRelationshipFormFieldState
    extends State<OnboardingRelationshipFormField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  @override
  void didUpdateWidget(OnboardingRelationshipFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final field = _fieldKey.currentState;
    if (oldWidget.value != widget.value &&
        field != null &&
        !field.hasInteractedByUser) {
      final next = widget.value;
      deferFormFieldDidChange(this, () {
        if (!field.mounted || field.hasInteractedByUser) return;
        field.didChange(next);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      builder: (field) {
        final l10n = AppLocalizations.of(context)!;
        final selected = _ownerRelationshipOptions.indexWhere(
          (p) => p.membershipLabel == widget.value,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingFieldLabel(l10n.onboardingYourRelationshipToBaby),
            const SizedBox(height: 8),
            OnboardingPillSelect(
              layout: OnboardingPillLayout.equalWidthRow,
              options: [
                for (final p in _ownerRelationshipOptions) p.label(l10n),
              ],
              semanticsIds: const [
                'onboarding_relationship_mother',
                'onboarding_relationship_father',
              ],
              selectedIndex: selected < 0 ? null : selected,
              selectedStyleForIndex: (_) => const OnboardingPillSelectedStyle(
                background: AppColors.sageTint,
                border: AppColors.primaryDark,
                foreground: AppColors.primaryDark,
              ),
              onSelected: (index) {
                // Store the canonical relationship_label, not the localized pill text.
                final label = _ownerRelationshipOptions[index].membershipLabel;
                final hadError = field.hasError;
                field.didChange(label);
                widget.onSelected(label);
                if (hadError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    field.validate();
                  });
                }
              },
            ),
            if (field.hasError) ...[
              const SizedBox(height: 4),
              Text(
                field.errorText!,
                style: TextStyle(
                  color: Theme.of(field.context).colorScheme.error,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Terms checkbox with tappable legal links (not inside [CheckboxListTile] title).
class OnboardingTermsAgreementCheckbox extends StatelessWidget {
  const OnboardingTermsAgreementCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = context.textStyles.bodySmall?.copyWith(
      color: AppColors.muted,
    );
    final link = context.textStyles.bodySmall?.copyWith(
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w600,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSemantics.container(
          'onboarding_terms_checkbox',
          Checkbox(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: PlaceholderRichText(
              message: (t) => l10n.onboardingAgreeToTerms(t[0], t[1]),
              style: muted,
              placeholderStyle: link,
              placeholders: [
                MessagePlaceholder(
                  label: l10n.onboardingTermsOfService,
                  onTap: onTermsTap,
                ),
                MessagePlaceholder(
                  label: l10n.onboardingPrivacyPolicy,
                  onTap: onPrivacyTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingPasswordField extends StatefulWidget {
  const OnboardingPasswordField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.validator,
    this.onFieldSubmitted,
    this.fieldKey,
    this.semanticsId,
    this.autovalidateMode,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Key? fieldKey;
  final String? semanticsId;
  final AutovalidateMode? autovalidateMode;

  @override
  State<OnboardingPasswordField> createState() =>
      _OnboardingPasswordFieldState();
}

class _OnboardingPasswordFieldState extends State<OnboardingPasswordField> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = widget.label ?? l10n.fieldPassword;
    final hint = widget.hint ?? l10n.actionCreatePassword;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingFieldLabel(label),
        const SizedBox(height: 8),
        _maybeSemanticsField(
          semanticsId: widget.semanticsId,
          child: AppTextFormField(
            key: widget.fieldKey,
            controller: widget.controller,
            obscureText: _obscure,
            validator: widget.validator,
            onFieldSubmitted: widget.onFieldSubmitted,
            textInputAction: TextInputAction.done,
            autovalidateMode: widget.autovalidateMode,
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: AppIconButton(
                semanticsId: widget.semanticsId == null
                    ? 'password_visibility'
                    : '${widget.semanticsId}_visibility',
                label: _obscure ? AppLocalizations.of(context)!.accountShowPassword : AppLocalizations.of(context)!.accountHidePassword,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingDivider extends StatelessWidget {
  OnboardingDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.colorScheme.outline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label ?? l10n.labelSignUpEmail,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class OnboardingHelperText extends StatelessWidget {
  const OnboardingHelperText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.muted, height: 1.4),
    );
  }
}

class OnboardingBottomLink extends StatelessWidget {
  const OnboardingBottomLink({
    super.key,
    required this.message,
    required this.actionText,
    required this.onTap,
    this.actionKey,
    this.semanticsId,
  });

  /// gen-l10n method for the sentence; its `{action}` placeholder becomes the link.
  final String Function(String action) message;
  final String actionText;
  final VoidCallback onTap;
  final Key? actionKey;

  /// Optional Maestro id for the whole link row.
  final String? semanticsId;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.muted);
    final link = muted?.copyWith(
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w700,
    );
    final Widget row = GestureDetector(
      key: actionKey,
      onTap: onTap,
      child: PlaceholderRichText(
        message: (t) => message(t[0]),
        style: muted,
        placeholderStyle: link,
        textAlign: TextAlign.center,
        placeholders: [MessagePlaceholder(label: actionText, onTap: onTap)],
      ),
    );
    final id = semanticsId;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: id == null ? row : AppSemantics.button(id, row),
    );
  }
}

class OnboardingPillSelectedStyle {
  const OnboardingPillSelectedStyle({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

/// How [OnboardingPillSelect] lays out options (see development.md onboarding UI).
enum OnboardingPillLayout {
  /// Intrinsic-width pills in a [Wrap] (e.g. create-baby gender).
  wrap,

  /// Equal-width columns in a full-width [Row] (e.g. Mother / Father).
  equalWidthRow,
}

class OnboardingPillSelect extends StatelessWidget {
  const OnboardingPillSelect({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.layout = OnboardingPillLayout.wrap,
    this.selectedStyleForIndex,
    this.semanticsIds,
  });

  final List<String> options;

  /// Optional Maestro ids, one per option (same order as [options]).
  final List<String>? semanticsIds;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final OnboardingPillLayout layout;
  final OnboardingPillSelectedStyle? Function(int index)? selectedStyleForIndex;

  @override
  Widget build(BuildContext context) {
    assert(
      layout != OnboardingPillLayout.equalWidthRow || options.length >= 2,
      'equalWidthRow requires at least two options',
    );

    assert(
      semanticsIds == null || semanticsIds!.length == options.length,
      'semanticsIds must match options',
    );

    final pills = List.generate(options.length, (index) {
      final selected = selectedIndex == index;
      final override = selected ? selectedStyleForIndex?.call(index) : null;
      Widget pill = _OnboardingChoicePill(
        label: options[index],
        selected: selected,
        selectedStyle: override,
        expandWidth: layout == OnboardingPillLayout.equalWidthRow,
        onTap: () => onSelected(index),
      );
      final ids = semanticsIds;
      if (ids != null) {
        pill = AppSemantics.button(ids[index], pill);
      }

      if (layout == OnboardingPillLayout.equalWidthRow) {
        return Expanded(child: pill);
      }
      return pill;
    });

    switch (layout) {
      case OnboardingPillLayout.wrap:
        return Wrap(
          spacing: AppMetrics.choicePillGap,
          runSpacing: AppMetrics.choicePillGap,
          children: pills,
        );
      case OnboardingPillLayout.equalWidthRow:
        return Row(
          children: [
            for (var i = 0; i < pills.length; i++) ...[
              if (i > 0) const SizedBox(width: AppMetrics.choicePillGap),
              pills[i],
            ],
          ],
        );
    }
  }
}

class _OnboardingChoicePill extends StatelessWidget {
  const _OnboardingChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedStyle,
    this.expandWidth = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final OnboardingPillSelectedStyle? selectedStyle;
  final bool expandWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = context.textStyles.labelMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: selected
          ? (selectedStyle?.foreground ?? AppColors.primaryDark)
          : colorScheme.onSurface,
    );

    final content = Text(
      label,
      textAlign: expandWidth ? TextAlign.center : null,
      style: labelStyle,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(
          minHeight: AppMetrics.choicePillMinHeight,
        ),
        width: expandWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.choicePillHorizontalPadding,
          vertical: AppMetrics.choicePillVerticalPadding,
        ),
        alignment: expandWidth ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected
              ? (selectedStyle?.background ?? AppColors.sageTint)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
          border: Border.all(
            color: selected
                ? (selectedStyle?.border ?? AppColors.primaryDark)
                : colorScheme.outline,
          ),
        ),
        child: content,
      ),
    );
  }
}

Widget _maybeSemanticsField({String? semanticsId, required Widget child}) {
  if (semanticsId == null) return child;
  return AppSemantics.textField(semanticsId, child);
}

/// Owner's own relationship on create-profile (stored as relationship_label).
const _ownerRelationshipOptions = [
  RelationshipPreset.mother,
  RelationshipPreset.father,
];
