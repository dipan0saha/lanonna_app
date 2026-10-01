import 'package:flutter/material.dart';

import '../../data/models/photo_models.dart';

class GalleryPhotoGrid extends StatelessWidget {
  const GalleryPhotoGrid({
    super.key,
    required this.photos,
    required this.onPhotoTap,
  });

  final List<PhotoSummary> photos;
  final void Function(PhotoSummary photo) onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () => onPhotoTap(photo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo.thumbUrl != null)
                  Image.network(photo.thumbUrl!, fit: BoxFit.cover)
                else
                  ColoredBox(
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.image_outlined)),
                  ),
                if (photo.status == 'pending')
                  Container(
                    color: Colors.black38,
                    alignment: Alignment.center,
                    child: const Text(
                      'Processing…',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
