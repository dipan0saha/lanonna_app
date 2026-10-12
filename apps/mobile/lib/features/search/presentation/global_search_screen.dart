import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_tab_body.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_section_title.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/media/cached_signed_image.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../calendar/domain/calendar_routes.dart';
import '../../gallery/domain/gallery_routes.dart';
import '../../home/data/home_repository.dart';
import '../../home/domain/app_routes.dart';
import '../../home/data/selected_baby_store.dart';
import '../data/search_repository.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  SearchResults? _results;
  var _loading = false;
  String? _babyId;
  String? _error;
  Timer? _debounce;
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    _resolveBaby();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolveBaby() async {
    final store = context.read<SelectedBabyStore>();
    final baby = await context.read<HomeRepository>().resolveSelectedBaby(store);
    if (baby != null && mounted) {
      setState(() => _babyId = baby.id);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _requestId += 1;
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String q) async {
    final babyId = _babyId;
    final query = q.trim();
    if (babyId == null || query.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<SearchRepository>().search(
        babyId: babyId,
        query: query,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      final message = apiErrorMessage(e);
      setState(() {
        _error = message;
        _results = null;
      });
      AppSnackBar.showAlert(context, message);
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        title: AppSemantics.textField(
          'search_field',
          AppTextField(
            kind: AppTextInputKind.none,
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search photos, events, registry…',
              border: InputBorder.none,
            ),
            onChanged: _onQueryChanged,
            onSubmitted: _runSearch,
          ),
        ),
      ),
      body: _babyId == null
          ? const Center(child: Text('Select a baby profile to search'))
          : AsyncTabBody(
              loading: _loading && results == null && _error == null,
              error: _error,
              onRetry: () => _runSearch(_controller.text),
              child: results == null
                  ? Center(
                      child: Text(
                        'Type to search',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  : results.isEmpty
                      ? Center(child: Text('No results for "${results.query}"'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (results.photos.isNotEmpty) ...[
                              const AppSectionTitle(title: 'Photos'),
                              for (final p in results.photos)
                                ListTile(
                                  leading: p.thumbUrl != null
                                      ? CachedSignedImage(
                                          imageUrl: p.thumbUrl,
                                          cacheKey: 'thumb-${p.id}',
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          onSignedUrlError: () {
                                            if (_controller.text.trim().isNotEmpty) {
                                              _runSearch(_controller.text);
                                            }
                                          },
                                        )
                                      : const Icon(Icons.photo_outlined),
                                  title: Text(p.caption ?? 'Photo'),
                                  onTap: () => context.push(
                                    GalleryRoutes.photoDetail(p.id),
                                  ),
                                ),
                            ],
                            if (results.events.isNotEmpty) ...[
                              const SizedBox(height: AppMetrics.sectionBlockSpacing),
                              const AppSectionTitle(title: 'Events'),
                              for (final e in results.events)
                                ListTile(
                                  leading: const Icon(Icons.event_outlined),
                                  title: Text(e.title),
                                  subtitle: Text(
                                    formatEventListDateTime(
                                      e.startsAt,
                                      Localizations.localeOf(context).toString(),
                                    ),
                                  ),
                                  onTap: () => context.push(
                                    CalendarRoutes.eventDetail(e.id),
                                  ),
                                ),
                            ],
                            if (results.registryItems.isNotEmpty) ...[
                              const SizedBox(height: AppMetrics.sectionBlockSpacing),
                              const AppSectionTitle(title: 'Registry'),
                              for (final r in results.registryItems)
                                ListTile(
                                  leading: const Icon(Icons.card_giftcard_outlined),
                                  title: Text(r.name),
                                  onTap: () => context.go('/registry'),
                                ),
                            ],
                            if (results.nameSuggestions.isNotEmpty) ...[
                              const SizedBox(height: AppMetrics.sectionBlockSpacing),
                              const AppSectionTitle(title: 'Names'),
                              for (final n in results.nameSuggestions)
                                ListTile(
                                  leading: const Icon(Icons.favorite_outline),
                                  title: Text(n.name),
                                  onTap: () => context.go(AppRoutes.gamification),
                                ),
                            ],
                          ],
                        ),
            ),
    );
  }
}
