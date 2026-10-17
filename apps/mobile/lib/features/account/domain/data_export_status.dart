import 'package:lanonna/l10n/app_localizations.dart';

/// Server-owned export job state (`export_jobs.status`).
enum DataExportStatus {
  pending('pending'),
  running('running'),
  ready('ready'),
  failed('failed');

  const DataExportStatus(this.apiValue);

  final String apiValue;

  static DataExportStatus fromApi(String? raw) => values.firstWhere(
        (s) => s.apiValue == raw,
        orElse: () => DataExportStatus.pending,
      );

  String label(AppLocalizations l10n) => switch (this) {
        DataExportStatus.pending => l10n.exportStatusPending,
        DataExportStatus.running => l10n.exportStatusRunning,
        DataExportStatus.ready => l10n.exportStatusReady,
        DataExportStatus.failed => l10n.exportStatusFailed,
      };
}
