import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/media/display_encode.dart';
import '../../../../core/media/pick_display_photo.dart';
import '../../../../core/widgets/app_modal_sheet.dart';
import '../../../../l10n/app_localizations.dart';

/// Camera or library source for a gallery upload. Returns `null` when the
/// sheet or the system picker is cancelled.
Future<XFile?> showPhotoSourceSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  return showAppModalSheet<XFile?>(
    context: context,
    title: l10n.actionAddPhoto2,
    subtitle: displayPhotoSourceHint(l10n),
    bodyBuilder: (context) {
      Future<void> pick(ImageSource source) async {
        final file = await pickDisplayPhoto(source: source);
        if (!context.mounted) return;
        Navigator.pop(context, file);
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.photoSourceCamera),
            onTap: () => pick(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.photoSourceLibrary),
            onTap: () => pick(ImageSource.gallery),
          ),
        ],
      );
    },
  );
}
