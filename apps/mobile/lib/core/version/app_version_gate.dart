import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import 'app_version_check.dart';

class AppVersionRequirement {
  const AppVersionRequirement({
    required this.minimumVersion,
    required this.storeUrl,
  });

  final String minimumVersion;
  final String storeUrl;

  factory AppVersionRequirement.fromJson(Map<String, dynamic> json) {
    return AppVersionRequirement(
      minimumVersion: json['minimum_version'] as String,
      storeUrl: json['store_url'] as String,
    );
  }
}

Future<AppVersionRequirement?> fetchAppVersionRequirement(
  ApiClient client,
) async {
  final platform = platformKeyForVersionCheck();
  try {
    final json = await client.getJsonPublic('/v1/app/version?platform=$platform');
    return AppVersionRequirement.fromJson(json);
  } catch (_) {
    return null;
  }
}

/// Full-screen block when the installed app is below API minimum (FR-SET-004).
class AppVersionBlockScreen extends StatelessWidget {
  const AppVersionBlockScreen({
    super.key,
    required this.storeUrl,
    required this.installedVersion,
    required this.minimumVersion,
  });

  final String storeUrl;
  final String installedVersion;
  final String minimumVersion;

  Future<void> _openStore() async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppMetrics.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Update required',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This version ($installedVersion) is no longer supported. '
                'Install $minimumVersion or newer to continue.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _openStore,
                child: const Text('Update in store'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runs version check once; shows [child] or a hard block screen.
class AppVersionGate extends StatefulWidget {
  const AppVersionGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate> {
  AppVersionRequirement? _block;
  String? _installedVersion;
  var _checking = true;

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _check();
  }

  Future<void> _check() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final installed = info.version;
    final client = context.read<ApiClient>();
    final requirement = await fetchAppVersionRequirement(client);
    if (!mounted) return;
    if (requirement != null &&
        isAppVersionBelowMinimum(installed, requirement.minimumVersion)) {
      setState(() {
        _block = requirement;
        _installedVersion = installed;
        _checking = false;
      });
      return;
    }
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final block = _block;
    if (block != null && _installedVersion != null) {
      return AppVersionBlockScreen(
        storeUrl: block.storeUrl,
        installedVersion: _installedVersion!,
        minimumVersion: block.minimumVersion,
      );
    }
    return widget.child;
  }
}
