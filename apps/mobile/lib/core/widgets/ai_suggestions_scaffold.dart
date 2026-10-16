import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'ai_suggestion_list_card.dart';
import 'app_chip.dart';

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
      appBar: AppBar(title: const Text('AI Suggestions')),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppMetrics.horizontalPadding,
              16,
              AppMetrics.horizontalPadding,
              16,
            ),
            child: Row(
              children: [
                for (final tab in tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppToggleChip(
                      label: tab.label,
                      selected: selectedTab == tab.key,
                      onTap: () => onTabChanged(tab.key),
                    ),
                  ),
              ],
            ),
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
