import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/announcement_repository.dart';
import 'widgets/announcement_keepsake_card.dart';

class AnnouncementShare {
  static Future<void> shareBabyAnnouncement(
    BuildContext context,
    String babyId,
  ) async {
    final repo = context.read<AnnouncementRepository>();
    final detail = await repo.fetch(babyId);
    if (detail == null) {
      await Share.share('Our baby announcement is here!');
      return;
    }
    final name = [
      detail.firstName,
      detail.lastName,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    final text = name.isEmpty
        ? 'Our baby announcement is here!'
        : 'Meet $name!';

    final boundaryKey = GlobalKey();
    final overlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -1000,
        top: 0,
        child: RepaintBoundary(
          key: boundaryKey,
          child: Material(
            color: Colors.white,
            child: AnnouncementKeepsakeCard(detail: detail),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(overlay);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final bytes = byteData.buffer.asUint8List();
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/announcement_share.png');
          await file.writeAsBytes(bytes);
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'image/png')],
            text: text,
            subject: 'Baby announcement',
          );
          overlay.remove();
          return;
        }
      }
    } catch (_) {
      // fall through to text share
    }
    overlay.remove();
    await Share.share(text);
  }
}
