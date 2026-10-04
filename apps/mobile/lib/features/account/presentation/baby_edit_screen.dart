import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../../core/domain/baby_summary.dart';
import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';

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
  final _picker = ImagePicker();
  String? _networkAvatarUrl;
  XFile? _photoFile;

  bool get _isBorn => _baby?.lifecycleStatus == 'born';
  bool get _isOwner => _baby?.role == 'owner';

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
      _networkAvatarUrl = baby?.avatarUrl;
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    if (!_isOwner) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _photoFile = file);
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
    final name = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      _name.text,
    );
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final dateIso = _date != null ? formatApiDate(_date!) : null;
      String? avatarUrl = _networkAvatarUrl;
      if (_photoFile != null && !kIsWeb) {
        avatarUrl = await DisplayPhotoUpload(context.read<ApiClient>()).uploadBabyAvatar(
          babyProfileId: widget.babyId,
          imageFile: File(_photoFile!.path),
        );
      }
      await context.read<HomeRepository>().updateBaby(
        widget.babyId,
        name: name,
        gender: _gender,
        expectedBirthDate: !_isBorn ? dateIso : null,
        actualBirthDate: _isBorn ? dateIso : null,
        avatarUrl: avatarUrl,
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
          if (_isOwner) ...[
            Center(
              child: PrototypePhotoUpload(
                imageFile: _photoFile,
                imageUrl: _photoFile == null ? _networkAvatarUrl : null,
                onTap: _saving ? null : _pickPhoto,
                onSignedUrlError: _load,
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Tap to change photo', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 16),
          ],
          AppLabeledTextField(
            label: 'Baby name',
            kind: AppTextInputKind.personName,
            controller: _name,
          ),
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
