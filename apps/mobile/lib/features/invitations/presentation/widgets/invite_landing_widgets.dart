import 'package:flutter/material.dart';

import '../../../../core/time/app_date_time.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/models/invitation_preview.dart';
import '../invite_date_subtitle.dart';

class InviteLandingHeader extends StatelessWidget {
  const InviteLandingHeader({
    super.key,
    required this.preview,
    required this.isCoOwner,
  });

  final InvitationPreview preview;
  final bool isCoOwner;

  @override
  Widget build(BuildContext context) {
    final inviter = preview.inviterDisplayName ?? 'A family member';
    final line = isCoOwner
        ? '$inviter invited you to co-own'
        : '$inviter invited you to follow';
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Text(
        line,
        textAlign: TextAlign.center,
        style: context.textStyles.bodyMedium?.copyWith(fontSize: 13),
      ),
    );
  }
}

class InviteBabyCard extends StatelessWidget {
  const InviteBabyCard({super.key, required this.preview});

  final InvitationPreview preview;

  @override
  Widget build(BuildContext context) {
    final babyName = preview.babyName ?? 'Baby';
    final subtitle = inviteBabyDateSubtitle(
      preview,
      localeNameForFormatting(context),
    );
    final text = context.textStyles;
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          Text('👶', style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(
            babyName,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: text.bodyMedium?.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class InviteReassureRow extends StatelessWidget {
  const InviteReassureRow({super.key, required this.isCoOwner});

  final bool isCoOwner;

  @override
  Widget build(BuildContext context) {
    final text = isCoOwner
        ? "As a co-owner, you'll have full access to edit, invite, and manage, just like the person who invited you."
        : 'A private space just for family & friends. Nothing here is public.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.textStyles.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.45,
                color: context.brand.shellIconMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InviteNotForYouLink extends StatelessWidget {
  const InviteNotForYouLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            'Not who this was meant for?',
            style: context.textStyles.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class RelationshipConfirmChip extends StatelessWidget {
  const RelationshipConfirmChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
      decoration: BoxDecoration(
        color: context.brand.sageTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primaryDark, width: 1.5),
      ),
      child: Text(
        label,
        style: context.textStyles.titleMedium,
      ),
    );
  }
}

class CoOwnerWelcomeBanner extends StatelessWidget {
  const CoOwnerWelcomeBanner({
    super.key,
    required this.babyName,
    required this.inviterName,
  });

  final String babyName;
  final String inviterName;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final text = context.textStyles;
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 60, 22, 0),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        color: brand.peachTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text('👑', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          Text(
            "You're officially an Owner!",
            textAlign: TextAlign.center,
            style: text.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'You now have full access to edit $babyName\'s profile, add events, manage the registry, and invite others, just like $inviterName.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              height: 1.45,
              color: brand.shellIconMuted,
            ),
          ),
        ],
      ),
    );
  }
}
