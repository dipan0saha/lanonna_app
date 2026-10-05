import 'package:flutter/material.dart';

import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/theme/app_brand_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import 'onboarding_typography.dart';

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
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      ],
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
    final muted = context.textStyles.bodySmall?.copyWith(color: AppColors.muted);
    final link = context.textStyles.bodySmall?.copyWith(
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w600,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('I agree to the ', style: muted),
                GestureDetector(
                  onTap: onTermsTap,
                  child: Text('Terms of Service', style: link),
                ),
                Text(' and ', style: muted),
                GestureDetector(
                  onTap: onPrivacyTap,
                  child: Text('Privacy Policy', style: link),
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
    this.label = 'Password',
    this.hint = 'Create a password',
    this.validator,
    this.onFieldSubmitted,
    this.fieldKey,
    this.semanticsId,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Key? fieldKey;
  final String? semanticsId;

  @override
  State<OnboardingPasswordField> createState() => _OnboardingPasswordFieldState();
}

class _OnboardingPasswordFieldState extends State<OnboardingPasswordField> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingFieldLabel(widget.label),
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
            decoration: InputDecoration(
              hintText: widget.hint,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
  const OnboardingDivider({super.key, this.label = 'or sign up with email'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.colorScheme.outline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
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
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.muted,
            height: 1.4,
          ),
    );
  }
}

class OnboardingBottomLink extends StatelessWidget {
  const OnboardingBottomLink({
    super.key,
    required this.prefix,
    required this.actionLabel,
    required this.onTap,
    this.actionKey,
  });

  final String prefix;
  final String actionLabel;
  final VoidCallback onTap;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: GestureDetector(
        key: actionKey,
        onTap: onTap,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            children: [
              TextSpan(text: prefix),
              TextSpan(
                text: actionLabel,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingSegmentedControlStyle {
  OnboardingSegmentedControlStyle({
    this.width,
    this.outerPadding = 5,
    this.outerRadius = 14,
    this.segmentGap = 4,
    this.height = 44,
    this.thumbRadius = 10,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w700,
    this.selectedLabelColor = AppColors.primaryDark,
    Color? unselectedLabelColor,
    this.duration = const Duration(milliseconds: 200),
    this.thumbShadow,
  }) : unselectedLabelColor =
            unselectedLabelColor ?? AppBrandTheme.light.segmentUnselectedLabel;

  static final standard = OnboardingSegmentedControlStyle();

  /// Matches prototype `.mini-toggle` (first-moment Boy/Girl).
  static final mini = OnboardingSegmentedControlStyle(
    width: 140,
    outerPadding: 3,
    outerRadius: 10,
    segmentGap: 3,
    height: 32,
    thumbRadius: 7,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    selectedLabelColor: AppColors.primaryDark,
    thumbShadow: [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ],
  );

  final double? width;
  final double outerPadding;
  final double outerRadius;
  final double segmentGap;
  final double height;
  final double thumbRadius;
  final double fontSize;
  final FontWeight fontWeight;
  final Color selectedLabelColor;
  final Color unselectedLabelColor;
  final Duration duration;
  final List<BoxShadow>? thumbShadow;
}

class OnboardingSegmentedControl extends StatelessWidget {
  OnboardingSegmentedControl({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onLeftTap,
    required this.onRightTap,
    this.leftSegmentKey,
    this.rightSegmentKey,
    OnboardingSegmentedControlStyle? style,
  }) : style = style ?? OnboardingSegmentedControlStyle.standard;

  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;
  final Key? leftSegmentKey;
  final Key? rightSegmentKey;
  final OnboardingSegmentedControlStyle style;

  @override
  Widget build(BuildContext context) {
    final track = Container(
      width: style.width,
      padding: EdgeInsets.all(style.outerPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F2),
        borderRadius: BorderRadius.circular(style.outerRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = (constraints.maxWidth - style.segmentGap) / 2;
          final thumbLeft = isLeftSelected ? 0.0 : segmentWidth + style.segmentGap;

          return SizedBox(
            height: style.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedPositioned(
                  duration: style.duration,
                  curve: Curves.easeInOut,
                  left: thumbLeft,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(style.thumbRadius),
                      boxShadow: style.thumbShadow ??
                          [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _SegmentLabel(
                        segmentKey: leftSegmentKey,
                        label: leftLabel,
                        selected: isLeftSelected,
                        onTap: onLeftTap,
                        style: style,
                      ),
                    ),
                    SizedBox(width: style.segmentGap),
                    Expanded(
                      child: _SegmentLabel(
                        segmentKey: rightSegmentKey,
                        label: rightLabel,
                        selected: !isLeftSelected,
                        onTap: onRightTap,
                        style: style,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return track;
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    this.segmentKey,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.style,
  });

  final Key? segmentKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final OnboardingSegmentedControlStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: segmentKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(style.thumbRadius),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: style.duration,
            curve: Curves.easeInOut,
            style: context.textStyles.bodyMedium!.copyWith(
              fontWeight: style.fontWeight,
              fontSize: style.fontSize,
              height: 1.2,
              color: selected ? style.selectedLabelColor : style.unselectedLabelColor,
            ),
            child: Text(label),
          ),
        ),
      ),
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

class OnboardingPillSelect extends StatelessWidget {
  const OnboardingPillSelect({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.selectedStyleForIndex,
  });

  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final OnboardingPillSelectedStyle? Function(int index)? selectedStyleForIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(options.length, (index) {
        final selected = selectedIndex == index;
        final override = selected ? selectedStyleForIndex?.call(index) : null;
        return GestureDetector(
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? (override?.background ?? AppColors.sageTint)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? (override?.border ?? AppColors.primaryDark)
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Text(
              options[index],
              style: context.textStyles.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? (override?.foreground ?? AppColors.primaryDark)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      }),
    );
  }
}

Widget _maybeSemanticsField({String? semanticsId, required Widget child}) {
  if (semanticsId == null) return child;
  return AppSemantics.textField(semanticsId, child);
}
