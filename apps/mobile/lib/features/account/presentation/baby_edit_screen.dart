import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../onboarding/data/models/baby_summary.dart';
import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';

class BabyEditScreen extends StatefulWidget {
  const BabyEditScreen({super.key, required this.babyId});

  final String babyId;

  @override
  State<BabyEditScreen> createState() => _BabyEditScreenState();
}

class _BabyEditScreenState extends State<BabyEditScreen> {
  final _name = TextEditingController();
  BabySummary? _baby;
  var _loading = true;
  var _saving = false;
  String? _gender;
  DateTime? _date;

  bool get _isBorn => _baby?.lifecycleStatus == 'born';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final babies = await context.read<HomeRepository>().listBabies();
    final baby = babies.where((b) => b.id == widget.babyId).firstOrNull;
    DateTime? parsed;
    final born = baby?.lifecycleStatus == 'born';
    final raw = born ? baby?.actualBirthDate : baby?.expectedBirthDate;
    if (raw != null) parsed = DateTime.tryParse(raw);
    setState(() {
      _baby = baby;
      _name.text = baby?.name ?? '';
      _gender = baby?.gender;
      _date = parsed;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final dateIso = _date != null ? formatApiDate(_date!) : null;
      await context.read<HomeRepository>().updateBabyFields(
        widget.babyId,
        name: _name.text.trim(),
        gender: _gender,
        expectedBirthDate: !_isBorn ? dateIso : null,
        actualBirthDate: _isBorn ? dateIso : null,
      );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PrototypeSubpageScaffold(
      title: 'Edit Baby',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Baby name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          Text('Gender', style: context.textStyles.labelLarge),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _gender = 'male'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        _gender == 'male' ? AppColors.sageTint : null,
                  ),
                  child: const Text('Boy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _gender = 'female'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        _gender == 'female' ? AppColors.peachTint : null,
                  ),
                  child: const Text('Girl'),
                ),
              ),
            ],
          ),
          ListTile(
            title: Text(_isBorn ? 'Date of birth' : 'Expected due date'),
            subtitle: Text(_date != null ? formatApiDate(_date!) : 'Tap to choose'),
            trailing: const Icon(Icons.calendar_today_outlined, size: 20),
            onTap: _pickDate,
          ),
          if (_baby != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Status: ${_baby!.lifecycleStatus}',
                style: context.textStyles.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save Changes'),
          ),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
