import 'package:flutter/material.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: const Center(child: Text('Gallery — upload flow next (FR-GAL)')),
      floatingActionButton: FloatingActionButton(
        key: const Key('upload_photo_fab'),
        onPressed: () {},
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
