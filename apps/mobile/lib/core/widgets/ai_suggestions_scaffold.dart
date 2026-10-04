import 'package:flutter/material.dart';

class AiSuggestionTab {
  const AiSuggestionTab({required this.key, required this.label});

  final String key;
  final String label;
}

class AiSuggestionListItem {
  const AiSuggestionListItem({
    required this.title,
    required this.description,
    required this.onAdd,
    this.semanticsIdentifier,
  });

  final String title;
  final String description;
  final VoidCallback onAdd;
  final String? semanticsIdentifier;
}

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
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final addButton = TextButton(
                                onPressed: item.onAdd,
                                child: const Text('+ Add'),
                              );
                              final trailing = item.semanticsIdentifier != null
                                  ? Semantics(
                                      identifier: item.semanticsIdentifier,
                                      button: true,
                                      child: addButton,
                                    )
                                  : addButton;
                              return ListTile(
                                title: Text(item.title),
                                subtitle: Text(item.description),
                                trailing: trailing,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
