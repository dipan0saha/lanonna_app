import 'package:flutter/material.dart';
import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/domain/relationship_preset.dart';
import '../../../../l10n/app_localizations.dart';

class OnboardingInviteRow extends StatelessWidget {
  const OnboardingInviteRow({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.relationship,
    required this.onRelationshipChanged,
    this.showOwnerBadge = false,
    this.onRemove,
    this.onFieldChanged,
    this.onEmailEditingComplete,
    this.membershipHint,
    this.emailValidator,
    this.autovalidateMode,
    this.relationshipOptions = RelationshipPreset.onboardingOptions,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final RelationshipPreset relationship;
  final ValueChanged<RelationshipPreset> onRelationshipChanged;
  final bool showOwnerBadge;
  final VoidCallback? onRemove;
  final VoidCallback? onFieldChanged;
  final VoidCallback? onEmailEditingComplete;
  final String? membershipHint;
  /// Runs inside the parent [Form] (the app's shared validation pattern).
  final FormFieldValidator<String>? emailValidator;
  final AutovalidateMode? autovalidateMode;
  final List<RelationshipPreset> relationshipOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border(
          top: BorderSide(
            color: showOwnerBadge ? AppColors.secondaryDark : AppColors.border,
            width: 1.5,
          ),
          right: BorderSide(
            color: showOwnerBadge ? AppColors.secondaryDark : AppColors.border,
            width: 1.5,
          ),
          bottom: BorderSide(
            color: showOwnerBadge ? AppColors.secondaryDark : AppColors.border,
            width: 1.5,
          ),
          left: BorderSide(
            color: showOwnerBadge ? AppColors.secondaryDark : AppColors.border,
            width: showOwnerBadge ? 3 : 1.5,
          ),
        ),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onRemove != null)
            Align(
              alignment: Alignment.centerRight,
              child: AppIconButton(
                semanticsId: 'invite_row_remove',
                label: l10n.onboardingRemoveInvite,
                onPressed: onRemove,
                color: AppColors.muted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
          AppTextField(
            kind: AppTextInputKind.personName,
            controller: nameController,
            onChanged: (_) => onFieldChanged?.call(),
            decoration: InputDecoration(
              hintText: l10n.labelName,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppTextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            validator: emailValidator,
            autovalidateMode: autovalidateMode,
            onChanged: (_) => onFieldChanged?.call(),
            onEditingComplete: onEmailEditingComplete,
            decoration: InputDecoration(
              hintText: l10n.labelEmailPhone,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          if (membershipHint != null && membershipHint!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              membershipHint!,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.brand.ownerBadgeText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<RelationshipPreset>(
            value: relationship,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: relationshipOptions
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(o.label(AppLocalizations.of(context)!)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onRelationshipChanged(v);
            },
          ),
          if (showOwnerBadge) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.peachTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.messagePerson,
                style: context.textStyles.bodyMedium?.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: context.brand.ownerBadgeText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
