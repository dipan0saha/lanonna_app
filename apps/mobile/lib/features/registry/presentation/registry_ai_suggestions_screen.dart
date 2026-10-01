import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/registry_suggestions_catalog.dart';
import '../domain/registry_routes.dart';
import 'registry_item_form_screen.dart';

class RegistryAiSuggestionsScreen extends StatefulWidget {
  const RegistryAiSuggestionsScreen({super.key});

  @override
  State<RegistryAiSuggestionsScreen> createState() =>
      _RegistryAiSuggestionsScreenState();
}

class _RegistryAiSuggestionsScreenState extends State<RegistryAiSuggestionsScreen> {
  var _tab = 'newborn';
  List<RegistrySuggestion> _items = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await RegistrySuggestionsCatalog.forTab(_tab);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

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
                _tabChip('newborn', 'Newborn (0–3mo)'),
                _tabChip('3to6', '3–6 months'),
                _tabChip('6to12', '6–12 months'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.description),
                        trailing: TextButton(
                          onPressed: () {
                            context.push(
                              RegistryRoutes.createItem,
                              extra: RegistryItemFormPrefill(
                                name: item.name,
                                description: item.description,
                              ),
                            );
                          },
                          child: const Text('+ Add'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String key, String label) {
    final selected = _tab == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _tab = key;
            _loading = true;
          });
          _load();
        },
      ),
    );
  }
}
