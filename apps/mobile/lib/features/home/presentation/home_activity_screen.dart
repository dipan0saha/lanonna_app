import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/home_repository.dart';
import '../data/models/home_summary.dart';
import 'widgets/home_activity_feed.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchMore();
  }

  Future<void> _fetchMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: ListView(
        children: [
          HomeActivityFeed(
            items: _items,
            babyId: widget.babyId,
            showViewAll: false,
          ),
          if (_hasMore)
            Center(
              child: TextButton(
                onPressed: _fetchMore,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Load more'),
              ),
            ),
        ],
      ),
    );
  }
}
