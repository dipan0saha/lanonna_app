import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../models/invite_relationship_option.dart';

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
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final InviteRelationshipOption relationship;
  final ValueChanged<InviteRelationshipOption> onRelationshipChanged;
  final bool showOwnerBadge;
  final VoidCallback? onRemove;
  final VoidCallback? onFieldChanged;
  final VoidCallback? onEmailEditingComplete;
  final String? membershipHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border(
          top: BorderSide(color: showOwnerBadge ? AppColors.secondaryDark : AppColors.border, width: 1.5),
          right: BorderSide(color: showOwnerBadge ? AppColors.secondaryDark : AppColors.border, width: 1.5),
          bottom: BorderSide(color: showOwnerBadge ? AppColors.secondaryDark : AppColors.border, width: 1.5),
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
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.muted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => onFieldChanged?.call(),
            decoration: const InputDecoration(
              hintText: 'Name',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => onFieldChanged?.call(),
            onEditingComplete: onEmailEditingComplete,
            decoration: const InputDecoration(
              hintText: 'Email or phone',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          DropdownButtonFormField<InviteRelationshipOption>(
            value: relationship,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: kInviteRelationshipOptions
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(o.pickerLabel),
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
                '👑 This person will also be a Baby Profile Owner',
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
