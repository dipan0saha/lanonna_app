import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../l10n/app_localizations.dart';
import '../media/cached_signed_image.dart';
import '../media/display_sized_image.dart';
import '../media/photo_selection.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// Renders a [PhotoSelection]: the picked local file, else the stored photo's
/// signed URL, else a placeholder icon. While [busy], a scrim and spinner sit
/// over the photo (announced as "Uploading photo…").
///
/// One renderer for every form photo slot so a picked photo always previews
/// immediately, before it is uploaded.
class PhotoSelectionPreview extends StatelessWidget {
  const PhotoSelectionPreview({
    super.key,
    required this.selection,
    required this.width,
    required this.height,
    this.circle = false,
    this.borderRadius = 0,
    this.framed = true,
    this.busy = false,
    this.onSignedUrlError,
    this.placeholderIcon = Icons.photo_camera_outlined,
  });

  final PhotoSelection selection;
  final double width;
  final double height;

  /// Circle (avatars) instead of a rounded rectangle.
  final bool circle;
  final double borderRadius;

  /// Input-style fill and strong border (form fields); off for thumbnails.
  final bool framed;
  final bool busy;

  final VoidCallback? onSignedUrlError;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(borderRadius),
        color: AppColors.inputFill,
        border: framed
            ? Border.all(
                color: AppColors.inputBorderStrong,
                width: AppMetrics.photoPickerBorderWidth,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [_content(), if (busy) const _BusyOverlay()],
      ),
    );
  }

  Widget _content() {
    final file = selection.localFile;
    if (file != null) return LocalPhotoImage(file: file);
    final url = selection.previewUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CachedSignedImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        onSignedUrlError: onSignedUrlError,
      );
    }
    return Center(
      child: Icon(
        placeholderIcon,
        size: AppMetrics.photoPickerIconSize,
        color: AppColors.muted,
      ),
    );
  }
}

/// A photo picked on this device, before it is uploaded.
class LocalPhotoImage extends StatelessWidget {
  const LocalPhotoImage({
    super.key,
    required this.file,
    this.fit = BoxFit.cover,
  });

  final XFile file;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // On web the picker returns a blob URL instead of a file path.
    final ImageProvider<Object> source = kIsWeb
        ? NetworkImage(file.path)
        : FileImage(File(file.path));
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // A picked photo is up to 2048 px; decode it at the slot's size.
    return LayoutBuilder(
      builder: (context, constraints) => Image(
        image: DisplaySizedImage.forSlot(
          source,
          logicalSize: constraints.biggest,
          devicePixelRatio: dpr,
          fit: fit,
        ),
        fit: fit,
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.photoUploadingLabel,
      liveRegion: true,
      child: const ColoredBox(
        color: AppColors.mediaBusyScrim,
        child: Center(
          child: SizedBox.square(
            dimension: AppMetrics.photoPickerBusyIndicatorSize,
            child: CircularProgressIndicator(
              strokeWidth: AppMetrics.photoPickerBusyStrokeWidth,
              color: AppColors.surface,
            ),
          ),
        ),
      ),
    );
  }
}
