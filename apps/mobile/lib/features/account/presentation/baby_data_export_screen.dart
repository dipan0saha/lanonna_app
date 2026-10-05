import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../data/account_repository.dart';

class BabyDataExportScreen extends StatefulWidget {
  const BabyDataExportScreen({super.key});

  @override
  State<BabyDataExportScreen> createState() => _BabyDataExportScreenState();
}

class _BabyDataExportScreenState extends State<BabyDataExportScreen> {
  DataExportJob? _job;
  var _loading = true;
  var _requesting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final baby = await context.read<HomeRepository>().resolveOwnerBaby(
      context.read<SelectedBabyStore>(),
    );
    final babyId = baby?.id;
    if (babyId == null) {
      setState(() {
        _loading = false;
        _job = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final job = await context.read<AccountRepository>().fetchLatestExport(babyId);
      if (mounted) setState(() => _job = job);
    } catch (e) {
      if (mounted) {
        setState(() => _job = null);
        AppSnackBar.showAlert(context, apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestExport() async {
    final baby = await context.read<HomeRepository>().resolveOwnerBaby(
      context.read<SelectedBabyStore>(),
    );
    final babyId = baby?.id;
    if (babyId == null) return;
    setState(() => _requesting = true);
    try {
      final job = await context.read<AccountRepository>().requestExport(babyId);
      if (mounted) setState(() => _job = job);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _openDownload() async {
    final url = _job?.downloadUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return PrototypeSubpageScaffold(
      title: 'Export baby data',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Download a JSON copy of photos metadata, calendar, registry, and activity for your selected baby.',
                    style: context.textStyles.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (job != null) ...[
                    Text('Status: ${job.status}', style: context.textStyles.labelLarge),
                    if (job.errorMessage != null)
                      Text(
                        job.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _requesting ? null : _requestExport,
                    child: Text(_requesting ? 'Requesting…' : 'Request new export'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: job?.downloadUrl != null ? _openDownload : null,
                    child: const Text('Download export'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _refresh, child: const Text('Refresh status')),
                ],
              ),
      ),
    );
  }
}
