import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/time/app_date_time.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'onboarding_fields.dart';
import 'onboarding_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Soft circular icon backdrop for onboarding carousel and verify screens.
class OnboardingIconBlob extends StatelessWidget {
  const OnboardingIconBlob({
    super.key,
    required this.backgroundColor,
    required this.child,
    this.size = 180,
  });

  final Color backgroundColor;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Muted caption under [PrototypePhotoUpload]; tappable to open the picker.
class OnboardingPhotoCaption extends StatelessWidget {
  const OnboardingPhotoCaption({
    super.key,
    required this.hasPhoto,
    this.onTap,
    this.addLabel = 'Add a photo',
    this.changeLabel = 'Change photo',
  });

  final bool hasPhoto;
  final VoidCallback? onTap;
  final String addLabel;
  final String changeLabel;

  @override
  Widget build(BuildContext context) {
    final label = hasPhoto ? changeLabel : addLabel;
    final style = context.textStyles.bodyMedium?.copyWith(
      fontSize: 12,
      color: AppColors.muted,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Semantics(
          button: onTap != null,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Text(label, style: style, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class PrototypePhotoUpload extends StatelessWidget {
  const PrototypePhotoUpload({
    super.key,
    this.imageFile,
    this.imageUrl,
    this.onTap,
    this.onSignedUrlError,
    this.size = 88,
  });

  final XFile? imageFile;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onSignedUrlError;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.inputFill,
          border: Border.all(color: AppColors.inputBorderStrong, width: 1.5),
        ),
        alignment: Alignment.center,
        child: _buildAvatarContent(size),
      ),
    );
  }

  Widget _buildAvatarContent(double size) {
    if (imageFile != null && !kIsWeb) {
      return ClipOval(
        child: Image.file(
          File(imageFile!.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedSignedImage(
          imageUrl: url,
          cacheKey: 'avatar-preview-$url',
          width: size,
          height: size,
          fit: BoxFit.cover,
          onSignedUrlError: onSignedUrlError,
        ),
      );
    }
    return const Icon(
      Icons.photo_camera_outlined,
      size: 26,
      color: AppColors.muted,
    );
  }
}

class PrototypeMomentCard extends StatelessWidget {
  const PrototypeMomentCard({
    super.key,
    required this.iconBackground,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final Color iconBackground;
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.bodyLarge?.copyWith(fontSize: 14)),
                    Text(
                      subtitle,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 11.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class PrototypeMiniGenderToggle extends StatelessWidget {
  const PrototypeMiniGenderToggle({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final BabyGender selected;
  final ValueChanged<BabyGender> onSelected;

  @override
  Widget build(BuildContext context) {
    assert(
      selected == BabyGender.male || selected == BabyGender.female,
      'Name suggestion gender is Boy or Girl only',
    );
    final l10n = AppLocalizations.of(context)!;

    return OnboardingSegmentedControl(
      style: OnboardingSegmentedControlStyle.mini,
      leftSegmentKey: const Key('prototype_mini_gender_boy'),
      rightSegmentKey: const Key('prototype_mini_gender_girl'),
      leftLabel: BabyGender.male.label(l10n),
      rightLabel: BabyGender.female.label(l10n),
      isLeftSelected: selected == BabyGender.male,
      onLeftTap: () {
        if (selected != BabyGender.male) onSelected(BabyGender.male);
      },
      onRightTap: () {
        if (selected != BabyGender.female) onSelected(BabyGender.female);
      },
    );
  }
}

class PrototypeInlineNameAdd extends StatelessWidget {
  const PrototypeInlineNameAdd({
    super.key,
    required this.controller,
    required this.onAdd,
    this.hint,
  });

  final TextEditingController controller;
  final VoidCallback onAdd;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            kind: AppTextInputKind.personName,
            controller: controller,
            decoration: InputDecoration(hintText: hint ?? l10n.actionAddName),
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 48,
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryButtonForeground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PrototypeAddAnotherButton extends StatelessWidget {
  const PrototypeAddAnotherButton({super.key, required this.onTap, this.label});

  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.inputBorderStrong,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Text(
          '+ ${label ?? l10n.actionAddAnother}',
          textAlign: TextAlign.center,
          style: context.textStyles.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class PrototypeDateField extends StatelessWidget {
  const PrototypeDateField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? placeholder
        : formatApiCalendarDateFromParts(
            value!,
            localeNameForFormatting(context),
          );
    final brand = context.brand;
    final fieldText = context.textStyles.bodyMedium?.copyWith(
      fontSize: 14,
      color: value == null ? brand.fieldPlaceholder : AppColors.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingFieldLabel(label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5),
              color: AppColors.surfaceElevated,
            ),
            child: Row(
              children: [
                Expanded(child: Text(display, style: fieldText)),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: brand.fieldPlaceholder,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PrototypeTimeField extends StatelessWidget {
  const PrototypeTimeField({
    super.key,
    required this.label,
    required this.time,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? time;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = time == null ? placeholder : time!.format(context);
    final brand = context.brand;
    final fieldText = context.textStyles.bodyMedium?.copyWith(
      fontSize: 14,
      color: time == null ? brand.fieldPlaceholder : AppColors.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingFieldLabel(label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5),
              color: AppColors.surfaceElevated,
            ),
            child: Row(
              children: [
                Expanded(child: Text(display, style: fieldText)),
                Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: brand.fieldPlaceholder,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
