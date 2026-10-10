import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<File?> showPhotoSourceSheet(BuildContext context) async {
  return showModalBottomSheet<File?>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      );
    },
  );
}
