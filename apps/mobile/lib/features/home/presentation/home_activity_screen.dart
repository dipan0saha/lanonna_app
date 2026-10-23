import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/widgets/activity/activity_feed_card.dart';
import '../../../core/widgets/app_load_more_button.dart';
import '../data/home_repository.dart';
import '../data/models/home_summary.dart';
import '../../../l10n/app_localizations.dart';

class HomeActivityScreen extends StatefulWidget {
  const HomeActivityScreen({super.key, required this.babyId});

  final String babyId;

  @override
  State<HomeActivityScreen> createState() => _HomeActivityScreenState();
}

class _HomeActivityScreenState extends State<HomeActivityScreen> {
  final List<HomeActivityItem> _items = [];
  var _offset = 0;
  var _loading = false;
  var _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMore();
  }

  Future<void> _fetchMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<HomeRepository>().fetchActivityPage(
        widget.babyId,
        offset: _offset,
      );
      setState(() {
        _items.addAll(page.items);
        _offset += page.items.length;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(AppLocalizations.of(context)!, e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.activityTitle)),
      body: _error != null && _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _fetchMore, child: Text(AppLocalizations.of(context)!.actionRetry)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                ActivityFeedCard(items: _items),
                if (_hasMore)
                  AppLoadMoreButton(loading: _loading, onPressed: _fetchMore),
              ],
            ),
    );
  }
}
