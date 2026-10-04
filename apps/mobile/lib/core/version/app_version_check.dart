import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Compares semantic versions `major.minor.patch` (build suffix ignored).
bool isAppVersionBelowMinimum(String current, String minimum) {
  final cur = _parseVersion(current);
  final min = _parseVersion(minimum);
  for (var i = 0; i < 3; i++) {
    if (cur[i] < min[i]) return true;
    if (cur[i] > min[i]) return false;
  }
  return false;
}

List<int> _parseVersion(String raw) {
  final name = raw.split('+').first.trim();
  final parts = name.split('.');
  final nums = <int>[];
  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      nums.add(int.tryParse(parts[i]) ?? 0);
    } else {
      nums.add(0);
    }
  }
  return nums;
}

String platformKeyForVersionCheck() {
  if (kIsWeb) return 'android';
  if (Platform.isIOS) return 'ios';
  return 'android';
}
