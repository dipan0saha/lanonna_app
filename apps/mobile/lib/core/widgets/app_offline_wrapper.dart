import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../network/connectivity_service.dart';
import 'offline_banner.dart';

/// App-wide shell: offline banner above routed content (PRD §5.2).
class AppOfflineWrapper extends StatelessWidget {
  const AppOfflineWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityService>().isOnline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isOnline ? const SizedBox.shrink() : const OfflineBanner(),
        ),
        Expanded(child: child),
      ],
    );
  }
}
