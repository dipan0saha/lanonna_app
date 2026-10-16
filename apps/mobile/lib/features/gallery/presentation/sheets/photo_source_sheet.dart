import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/media/display_encode.dart';
import '../../../../core/widgets/app_modal_sheet.dart';
import '../../../../l10n/app_localizations.dart';

Future<File?> showPhotoSourceSheet(BuildContext context) async {
  return showAppModalSheet<File?>(
    context: context,
    title: 'Add a Photo',
    subtitle: displayPhotoSourceHint(),
    bodyBuilder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(AppLocalizations.of(context)!.photoSourceCamera),
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
            title: Text(AppLocalizations.of(context)!.photoSourceLibrary),
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
        ],
      );
    },
  );
}
