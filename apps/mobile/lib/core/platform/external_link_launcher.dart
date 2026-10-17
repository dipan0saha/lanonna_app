import 'dart:async';
import 'package:lanonna/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_snackbar.dart';

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

/// Opens [uri] outside the app. A failure shows a snackbar and, by default,
/// a Copy link action. [launch] is for tests.
Future<void> openExternalLink(
  BuildContext context,
  Uri uri, {
  bool copyFallback = true,
  String? failureMessage,
  ExternalUrlLauncher? launch,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final failure = failureMessage ?? l10n.linkOpenFailedCopy;
  final opener = launch ?? _launchExternal;
  var opened = false;
  try {
    opened = await opener(uri);
  } on PlatformException {
    opened = false;
  }
  if (opened || !context.mounted) return;
  if (!copyFallback) {
    AppSnackBar.showAlert(context, failure);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final controller = AppSnackBar.showAlertWithAction(
    context,
    failure,
    actionLabel: l10n.linkCopyAction,
    onAction: () {
      Clipboard.setData(ClipboardData(text: uri.toString()));
    },
  );
  unawaited(
    controller.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.linkCopied),
          duration: AppSnackBar.infoDuration,
          persist: false,
        ),
      );
    }),
  );
}

Future<bool> _launchExternal(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
