import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/data/home_refresh_signal.dart';
import '../data/gallery_repository.dart';

/// Refreshes gallery shell tabs (via [GalleryRepository]) and home/teasers (via [HomeRefreshSignal]).
void notifyGalleryDataChanged(BuildContext context) {
  context.read<GalleryRepository>().markGalleryChanged();
  context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
}
