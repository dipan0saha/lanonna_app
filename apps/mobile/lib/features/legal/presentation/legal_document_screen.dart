import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/widgets/prototype_subpage_scaffold.dart';

enum LegalDocumentKind { terms, privacy }

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    final asset = switch (widget.kind) {
      LegalDocumentKind.terms => 'assets/legal/terms.html',
      LegalDocumentKind.privacy => 'assets/legal/privacy.html',
    };
    _controller = WebViewController()
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        }),
      )
      ..loadFlutterAsset(asset);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      LegalDocumentKind.terms => 'Terms of Service',
      LegalDocumentKind.privacy => 'Privacy Policy',
    };
    return PrototypeSubpageScaffold(
      title: title,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
