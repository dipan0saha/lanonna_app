import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/input/app_text_input_kind.dart';
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/selected_baby_store.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/baby_lifecycle.dart';
import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';

class BabyCreateScreen extends StatefulWidget {
  const BabyCreateScreen({super.key});

  @override
  State<BabyCreateScreen> createState() => _BabyCreateScreenState();
}

class _BabyCreateScreenState extends State<BabyCreateScreen> {
  final _name = TextEditingController();
  var _lifecycle = BabyLifecycle.expecting;
  String? _gender; // male | female | unknown
  DateTime? _date;
  var _saving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final name = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      _name.text,
    );
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<OnboardingRepository>();
      final expected = _lifecycle == BabyLifecycle.expecting && _date != null
          ? formatApiDate(_date!)
          : null;
      final actual = _lifecycle == BabyLifecycle.born && _date != null
          ? formatApiDate(_date!)
          : null;
      final baby = await repo.createBaby(
        name: name,
        gender: _gender,
        lifecycleStatus: _lifecycle.apiValue,
        expectedBirthDate: expected,
        actualBirthDate: actual,
      );
      await context.read<SelectedBabyStore>().setSelectedBabyId(baby.id);
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrototypeSubpageScaffold(
      title: 'Add Baby',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppLabeledTextField(
            label: 'Baby name',
            kind: AppTextInputKind.personName,
            controller: _name,
          ),
          Text('Status', style: context.textStyles.labelLarge),
          SegmentedButton<BabyLifecycle>(
            segments: const [
              ButtonSegment(value: BabyLifecycle.expecting, label: Text('Expecting')),
              ButtonSegment(value: BabyLifecycle.born, label: Text('Born')),
            ],
            selected: {_lifecycle},
            onSelectionChanged: (s) => setState(() => _lifecycle = s.first),
          ),
          const SizedBox(height: 12),
          Text('Gender (optional)', style: context.textStyles.labelLarge),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Boy'),
                selected: _gender == 'male',
                onSelected: (_) => setState(() => _gender = 'male'),
              ),
              ChoiceChip(
                label: const Text('Girl'),
                selected: _gender == 'female',
                onSelected: (_) => setState(() => _gender = 'female'),
              ),
            ],
          ),
          ListTile(
            title: Text(
              _lifecycle == BabyLifecycle.expecting
                  ? 'Expected due date'
                  : 'Date of birth',
            ),
            subtitle: Text(_date != null ? formatApiDate(_date!) : 'Tap to choose'),
            trailing: const Icon(Icons.calendar_today_outlined, size: 20),
            onTap: _pickDate,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Creating…' : 'Create Baby'),
          ),
        ],
      ),
    );
  }
}
