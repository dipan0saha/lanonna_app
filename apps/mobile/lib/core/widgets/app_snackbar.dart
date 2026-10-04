import 'package:flutter/material.dart';

/// Central snackbar durations and helpers (PRD §5.1 feedback).
abstract final class AppSnackBar {
  /// Short acknowledgments (success, “done”) — no action button.
  static const Duration infoDuration = Duration(seconds: 1);

  /// Validation, errors, and copy the user should read.
  static const Duration alertDuration = Duration(seconds: 4);

  static void showInfo(BuildContext context, String message) {
    _show(context, message, infoDuration);
  }

  static void showAlert(BuildContext context, String message) {
    _show(context, message, alertDuration);
  }

  static void showInfoWithMessenger(
    ScaffoldMessengerState? messenger,
    String message,
  ) {
    if (messenger == null) return;
    messenger.showSnackBar(_bar(message, infoDuration));
  }

  static void showAlertWithMessenger(
    ScaffoldMessengerState? messenger,
    String message,
  ) {
    if (messenger == null) return;
    messenger.showSnackBar(_bar(message, alertDuration));
  }

  static void _show(BuildContext context, String message, Duration duration) {
    ScaffoldMessenger.of(context).showSnackBar(_bar(message, duration));
  }

  static SnackBar _bar(String message, Duration duration) {
    return SnackBar(
      content: Text(message),
      duration: duration,
      persist: false,
    );
  }
}
