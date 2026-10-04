import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Optional caption before uploading a gallery photo. Returns trimmed caption or `null` if skipped.
Future<String?> showPhotoUploadCaptionSheet(
  BuildContext context, {
  required File imageFile,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PhotoUploadCaptionSheet(imageFile: imageFile),
  );
}

class _PhotoUploadCaptionSheet extends StatefulWidget {
  const _PhotoUploadCaptionSheet({required this.imageFile});

  final File imageFile;

  @override
  State<_PhotoUploadCaptionSheet> createState() => _PhotoUploadCaptionSheetState();
}

class _PhotoUploadCaptionSheetState extends State<_PhotoUploadCaptionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _post() {
    final text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _controller.text,
    );
    Navigator.pop(context, text.isEmpty ? null : text);
  }

  void _skip() => Navigator.pop(context, null);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add to gallery', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Image.file(widget.imageFile, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            AppSemantics.textField(
              'gallery_upload_caption',
              AppTextField(
                kind: AppTextInputKind.prose,
                controller: _controller,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Add a caption…',
                  counterText: '',
                ),
                onSubmitted: (_) => _post(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppSemantics.button(
                    'gallery_upload_skip',
                    OutlinedButton(onPressed: _skip, child: const Text('Skip')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppSemantics.button(
                    'gallery_upload_post',
                    FilledButton(onPressed: _post, child: const Text('Post')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
