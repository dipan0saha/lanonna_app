import 'package:flutter/material.dart';

import 'ai_suggestion_list_card.dart';

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
  });

  final List<AiSuggestionTab> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabChanged;
  final bool loading;
  final Future<void> Function() onRefresh;
  final List<AiSuggestionListItem> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Suggestions')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (final tab in tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(tab.label),
                      selected: selectedTab == tab.key,
                      onSelected: (_) => onTabChanged(tab.key),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
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
