import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_sheet_handle.dart';

import 'package:image_picker/image_picker.dart';

import '../../../../core/media/display_encode.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

Future<File?> showPhotoSourceSheet(BuildContext context) async {
  return showModalBottomSheet<File?>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppMetrics.surfaceRadius),
      ),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.horizontalPadding,
            8,
            AppMetrics.horizontalPadding,
            12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSheetHandle(),
              Text(
                'Add a Photo',
                style: context.textStyles.titleSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xxs),
              Text(
                displayPhotoSourceHint(),
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () async {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 2048,
                    imageQuality: 85,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context, file != null ? File(file.path) : null);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from library'),
                onTap: () async {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 2048,
                    imageQuality: 85,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context, file != null ? File(file.path) : null);
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
