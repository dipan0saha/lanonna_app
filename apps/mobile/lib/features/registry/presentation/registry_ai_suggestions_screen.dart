import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/ai_suggestions_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../data/registry_repository.dart';
import '../data/registry_suggestions_catalog.dart';
import '../domain/registry_routes.dart';
import '../domain/registry_suggestion_availability.dart';
import 'registry_item_form_screen.dart';

class RegistryAiSuggestionsScreen extends StatefulWidget {
  const RegistryAiSuggestionsScreen({super.key});

  @override
  State<RegistryAiSuggestionsScreen> createState() =>
      _RegistryAiSuggestionsScreenState();
}

class _RegistryAiSuggestionsScreenState extends State<RegistryAiSuggestionsScreen> {
  static const _tabs = [
    AiSuggestionTab(key: 'expecting', label: 'Expecting'),
    AiSuggestionTab(key: 'newborn', label: 'Newborn (0–3mo)'),
    AiSuggestionTab(key: '3to6', label: '3–6 months'),
    AiSuggestionTab(key: '6to12', label: '6–12 months'),
  ];

  var _tab = 'expecting';
  List<RegistrySuggestion> _items = [];
  var _loading = true;
  var _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final baby = await homeRepo.resolveSelectedBaby(store);
    if (mounted) {
      setState(() {
        _tab = RegistrySuggestionsCatalog.defaultTabForLifecycle(
          baby?.lifecycleStatus,
        );
      });
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final homeRepo = context.read<HomeRepository>();
      final regRepo = context.read<RegistryRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      final catalog = await RegistrySuggestionsCatalog.forTab(_tab);
      if (baby == null) {
        setState(() {
          _items = catalog;
          _loading = false;
        });
        return;
      }
      final registryItems = await regRepo.listItems(baby.id);
      setState(() {
        _items = availableSuggestions(catalog, registryItems);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackBar.showAlert(
          context,
          'Could not load suggestions: ${apiErrorMessage(e)}',
        );
      }
    }
  }

  Future<void> _addSuggestion(RegistrySuggestion item) async {
    final added = await context.push<bool>(
      RegistryRoutes.createItem,
      extra: RegistryItemFormPrefill(
        name: item.name,
        description: item.description,
        catalogSuggestionId: item.id,
      ),
    );
    if (added == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AiSuggestionsScaffold(
      tabs: _tabs,
      selectedTab: _tab,
      onTabChanged: (key) {
        setState(() => _tab = key);
        _load();
      },
      loading: _loading,
      onRefresh: _load,
      emptyMessage: 'All suggestions in this stage are on your registry.',
      items: _items
          .map(
            (item) => AiSuggestionListItem(
              title: item.name,
              description: item.description,
              onAdd: () => _addSuggestion(item),
              semanticsIdentifier: 'registry_suggestion_add_${item.id}',
            ),
          )
          .toList(),
    );
  }
}
