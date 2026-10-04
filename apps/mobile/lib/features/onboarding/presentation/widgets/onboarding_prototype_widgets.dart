import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../domain/baby_gender.dart';
import 'onboarding_fields.dart';
import 'onboarding_typography.dart';

/// Organic shape art from the HTML prototype (`.icon-blob`).
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
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(44),
          topRight: Radius.circular(56),
          bottomRight: Radius.circular(60),
          bottomLeft: Radius.circular(40),
        ),
      ),
      alignment: Alignment.center,
      child: child,
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
    this.label = 'Add a photo',
    this.size = 88,
    this.showLabel = true,
  });

  final XFile? imageFile;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onSignedUrlError;
  final String label;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF1F1F2),
              border: Border.all(color: const Color(0xFFCFCFD1), width: 1.5),
            ),
            alignment: Alignment.center,
            child: _buildAvatarContent(size),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: context.textStyles.bodyMedium?.copyWith(fontSize: 12),
          ),
        ],
      ],
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
    return const Icon(Icons.photo_camera_outlined, size: 26, color: AppColors.muted);
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
                    Text(
                      title,
                      style: text.bodyLarge?.copyWith(fontSize: 14),
                    ),
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

class PrototypePresetChip extends StatelessWidget {
  const PrototypePresetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.sageTint : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          '+ $label',
          style: context.textStyles.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
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

    return OnboardingSegmentedControl(
      style: OnboardingSegmentedControlStyle.mini,
      leftSegmentKey: const Key('prototype_mini_gender_boy'),
      rightSegmentKey: const Key('prototype_mini_gender_girl'),
      leftLabel: 'Boy',
      rightLabel: 'Girl',
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
    this.hint = 'Add a name...',
  });

  final TextEditingController controller;
  final VoidCallback onAdd;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            kind: AppTextInputKind.personName,
            controller: controller,
            decoration: InputDecoration(hintText: hint),
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
              child: const Center(
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
  const PrototypeAddAnotherButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCFCFD1), width: 1.5, style: BorderStyle.solid),
        ),
        child: Text(
          '+ Add another',
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
        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';
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
              color: const Color(0xFFFCFCFD),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(display, style: fieldText),
                ),
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
