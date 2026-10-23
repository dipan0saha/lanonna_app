import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_error_message.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/widgets/app_load_more_button.dart';
import '../../../../core/widgets/app_modal_sheet.dart';
import '../../data/calendar_repository.dart';
import '../../data/models/calendar_models.dart';
import 'calendar_event_list_tile.dart';

Future<void> showCalendarPastEventsSheet(
  BuildContext context, {
  required String babyId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  await showAppModalSheet<void>(
    context: context,
    title: l10n.calendarPastEventsTitle,
    subtitle: l10n.calendarPastEventsSubtitle,
    bodyBuilder: (ctx) => _CalendarPastEventsBody(babyId: babyId),
  );
}

class _CalendarPastEventsBody extends StatefulWidget {
  const _CalendarPastEventsBody({required this.babyId});

  final String babyId;

  @override
  State<_CalendarPastEventsBody> createState() => _CalendarPastEventsBodyState();
}

class _CalendarPastEventsBodyState extends State<_CalendarPastEventsBody> {
  static const _pageSize = 30;

  List<CalendarEvent> _events = [];
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = false;
  var _offset = 0;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final page = await context.read<CalendarRepository>().listPastEventsPage(
        widget.babyId,
        offset: 0,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _events = page.items;
        _hasMore = page.hasMore;
        _offset = page.items.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = apiErrorMessage(AppLocalizations.of(context)!, e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<CalendarRepository>().listPastEventsPage(
        widget.babyId,
        offset: _offset,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _events = [..._events, ...page.items];
        _hasMore = page.hasMore;
        _offset += page.items.length;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Column(
        children: [
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: AppMetrics.listRowBottomGap),
          FilledButton(
            onPressed: _loadInitial,
            child: Text(l10n.actionRetry),
          ),
        ],
      );
    }
    if (_events.isEmpty) {
      return Text(l10n.calendarPastEventsEmpty);
    }
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final e in _events) CalendarEventListTile(event: e),
        if (_hasMore)
          AppLoadMoreButton(loading: _loadingMore, onPressed: _loadMore),
      ],
    );
  }
}
