import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../data/announcement_repository.dart';

class AnnouncementCreateScreen extends StatefulWidget {
  const AnnouncementCreateScreen({super.key, required this.babyId});

  final String babyId;

  @override
  State<AnnouncementCreateScreen> createState() => _AnnouncementCreateScreenState();
}

class _AnnouncementCreateScreenState extends State<AnnouncementCreateScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _weight = TextEditingController();
  final _length = TextEditingController();
  final _picker = ImagePicker();

  var _saving = false;
  var _loading = true;
  String? _gender; // male | female
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  XFile? _photo;
  String? _existingPhotoUrl;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final detail =
        await context.read<AnnouncementRepository>().fetch(widget.babyId);
    if (detail != null) {
      _first.text = detail.firstName ?? '';
      _last.text = detail.lastName ?? '';
      _weight.text = detail.weightText ?? '';
      _length.text = detail.lengthText ?? '';
      _gender = detail.gender;
      if (detail.birthDate != null) {
        _birthDate = DateTime.tryParse(detail.birthDate!);
      }
      if (detail.birthTime != null && detail.birthTime!.contains(':')) {
        final parts = detail.birthTime!.split(':');
        if (parts.length >= 2) {
          _birthTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 12,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      _existingPhotoUrl = detail.photoDisplayUrl;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _photo = file);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) setState(() => _birthTime = picked);
  }

  String? _formatBirthDate() {
    if (_birthDate == null) return null;
    final d = _birthDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String? _formatBirthTime() {
    if (_birthTime == null) return null;
    final t = _birthTime!;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      String? photoId;
      if (_photo != null && !kIsWeb) {
        photoId = await DisplayPhotoUpload(context.read<ApiClient>())
            .uploadGalleryPhoto(
          babyProfileId: widget.babyId,
          imageFile: File(_photo!.path),
        );
      }
      await context.read<AnnouncementRepository>().save(
        widget.babyId,
        firstName: _first.text.trim(),
        lastName: _last.text.trim().isEmpty ? null : _last.text.trim(),
        gender: _gender,
        birthDate: _formatBirthDate(),
        birthTime: _formatBirthTime(),
        weightText: _weight.text.trim().isEmpty ? null : _weight.text.trim(),
        lengthText: _length.text.trim().isEmpty ? null : _length.text.trim(),
        photoId: photoId,
      );
      if (mounted) context.go('/baby/${widget.babyId}/announcement');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _genderSegment(String label, String value) {
    final selected = _gender == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          onPressed: () => setState(() => _gender = value),
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? AppColors.sageTint : null,
            side: BorderSide(
              color: selected ? AppColors.primaryDark : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PrototypeSubpageScaffold(
      title: 'Announce Arrival',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            'Share the news with family. They will see a keepsake card with photo and details.',
            style: context.textStyles.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Center(
            child: PrototypePhotoUpload(
              imageFile: _photo,
              imageUrl: _existingPhotoUrl,
              onTap: _pickPhoto,
              label: 'Baby photo',
              size: 100,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('announcement_first_name'),
            controller: _first,
            decoration: const InputDecoration(labelText: 'First name'),
            textCapitalization: TextCapitalization.words,
          ),
          TextField(
            controller: _last,
            decoration: const InputDecoration(labelText: 'Last name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          Text('Gender', style: context.textStyles.labelLarge),
          Row(
            children: [
              _genderSegment('Boy', 'male'),
              _genderSegment('Girl', 'female'),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of birth'),
            subtitle: Text(_formatBirthDate() ?? 'Tap to choose'),
            trailing: const Icon(Icons.calendar_today_outlined, size: 20),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Time of birth'),
            subtitle: Text(_formatBirthTime() ?? 'Optional'),
            trailing: const Icon(Icons.schedule_outlined, size: 20),
            onTap: _pickTime,
          ),
          TextField(
            controller: _weight,
            decoration: const InputDecoration(labelText: 'Weight'),
          ),
          TextField(
            controller: _length,
            decoration: const InputDecoration(labelText: 'Length'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save Announcement'),
          ),
        ],
      ),
    );
  }
}
