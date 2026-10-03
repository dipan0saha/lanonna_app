import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/registry_repository.dart';

class RegistryItemFormPrefill {
  RegistryItemFormPrefill({required this.name, this.description});

  final String name;
  final String? description;
}

class RegistryItemFormScreen extends StatefulWidget {
  const RegistryItemFormScreen({
    super.key,
    this.itemId,
    this.initialName,
    this.initialDescription,
  });

  final String? itemId;
  final String? initialName;
  final String? initialDescription;

  bool get isEdit => itemId != null;

  @override
  State<RegistryItemFormScreen> createState() => _RegistryItemFormScreenState();
}

class _RegistryItemFormScreenState extends State<RegistryItemFormScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _link = TextEditingController();
  var _priority = 3;
  BabySummary? _baby;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
    _desc.text = widget.initialDescription ?? '';
    _loadBaby();
  }

  Future<void> _loadBaby() async {
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final baby = await homeRepo.resolveSelectedBaby(store);
    setState(() => _baby = baby);
    if (widget.isEdit && baby != null) {
      final items = await context.read<RegistryRepository>().listItems(baby.id);
      final item = items.where((i) => i.id == widget.itemId).firstOrNull;
      if (item != null) {
        _name.text = item.name;
        _desc.text = item.description ?? '';
        _link.text = item.productUrl ?? '';
        _priority = item.priority;
        setState(() {});
      }
    }
  }

  Future<void> _save() async {
    final baby = _baby;
    if (baby == null || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<RegistryRepository>();
      if (widget.isEdit) {
        await repo.updateItem(
          baby.id,
          widget.itemId!,
          name: _name.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          productUrl: _link.text.trim().isEmpty ? null : _link.text.trim(),
          priority: _priority,
        );
      } else {
        await repo.createItem(
          baby.id,
          name: _name.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          productUrl: _link.text.trim().isEmpty ? null : _link.text.trim(),
          priority: _priority,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final baby = _baby;
    if (baby == null || !widget.isEdit) return;
    await context.read<RegistryRepository>().deleteItem(baby.id, widget.itemId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Registry Item' : 'Add Registry Item'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Item Name'),
          ),
          TextField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 3,
          ),
          TextField(
            controller: _link,
            decoration: const InputDecoration(labelText: 'Link (optional)'),
          ),
          Text('Priority: $_priority'),
          Slider(
            value: _priority.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_priority',
            onChanged: (v) => setState(() => _priority = v.round()),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.isEdit ? 'Save Changes' : 'Add Item'),
          ),
          if (widget.isEdit) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Item'),
            ),
          ],
        ],
      ),
    );
  }
}
