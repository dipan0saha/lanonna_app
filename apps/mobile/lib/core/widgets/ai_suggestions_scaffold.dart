import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'ai_suggestion_list_card.dart';
import 'app_chip.dart';
import '../../l10n/app_localizations.dart';

export 'ai_suggestion_list_card.dart'
    show AiSuggestionListItem, AiSuggestionTab;

class AiSuggestionsScaffold extends StatelessWidget {
  const AiSuggestionsScaffold({
    super.key,
    required this.tabs,
    required this.selectedTab,
    required this.onTabChanged,
    required this.loading,
    required this.onRefresh,
    required this.items,
    required this.emptyMessage,
    this.subtitle,
  });

  final List<AiSuggestionTab> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabChanged;
  final bool loading;
  final Future<void> Function() onRefresh;
  final List<AiSuggestionListItem> items;
  final String emptyMessage;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.aiSuggestionsTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null && subtitle!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppMetrics.horizontalPadding,
                0,
                AppMetrics.horizontalPadding,
                8,
              ),
              child: Text(
                subtitle!,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
          AppToggleChipBar<String>(
            options: [
              for (final tab in tabs) AppToggleChipOption(tab.key, tab.label),
            ],
            selected: selectedTab,
            onSelected: onTabChanged,
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 48),
                              Center(
                                child: Padding(
                                  padding: AppMetrics.pageHorizontalInsets,
                                  child: Text(
                                    emptyMessage,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              AiSuggestionListCard(items: items),
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
