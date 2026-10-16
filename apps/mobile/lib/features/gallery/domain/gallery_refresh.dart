import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../data/gallery_repository.dart';

/// Refreshes gallery shell tabs (via [GalleryRepository]) and home/teasers (via [HomeRefreshSignal]).
void notifyGalleryDataChanged(BuildContext context) {
  final store = context.read<SelectedBabyStore>();
  final babyId = store.selectedBabyId;
  if (babyId != null) {
    context.read<HomeRepository>().invalidateHomeSummary(babyId);
  }
  context.read<GalleryRepository>().markGalleryChanged();
  context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
}
