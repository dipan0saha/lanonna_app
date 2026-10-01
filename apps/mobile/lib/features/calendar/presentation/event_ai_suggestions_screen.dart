import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../data/event_suggestions_catalog.dart';
import '../domain/calendar_routes.dart';
import 'event_form_screen.dart';

class EventAiSuggestionsScreen extends StatefulWidget {
  const EventAiSuggestionsScreen({super.key});

  @override
  State<EventAiSuggestionsScreen> createState() =>
      _EventAiSuggestionsScreenState();
}

class _EventAiSuggestionsScreenState extends State<EventAiSuggestionsScreen> {
  List<EventSuggestion> _items = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final baby = await homeRepo.resolveSelectedBaby(store);
    final lifecycle = baby?.lifecycleStatus ?? 'expecting';
    final items = await EventSuggestionsCatalog.forLifecycle(lifecycle);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggested events')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.description),
                  onTap: () {
                    context.push(
                      CalendarRoutes.createEvent,
                      extra: EventFormPrefill(
                        title: item.title,
                        description: item.description,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class EventFormPrefill {
  EventFormPrefill({required this.title, required this.description});

  final String title;
  final String description;
}
