import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../data/account_repository.dart';

class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({super.key});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _picker = ImagePicker();
  String? _email;
  String? _networkAvatarUrl;
  XFile? _photoFile;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final account = await context.read<AccountRepository>().fetchAccount();
    final name = account.displayName ?? '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      _firstName.text = parts.first;
      _lastName.text = parts.sublist(1).join(' ');
    } else {
      _firstName.text = name;
    }
    _email = account.email;
    _networkAvatarUrl = account.avatarUrl;
    setState(() {});
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _photoFile = file);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final displayName =
          '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      String? avatarUrl = _networkAvatarUrl;
      if (_photoFile != null && !kIsWeb) {
        avatarUrl = await DisplayPhotoUpload(context.read<ApiClient>()).uploadProfileAvatar(
          imageFile: File(_photoFile!.path),
        );
      }
      await context.read<AccountRepository>().updateProfile(
        displayName: displayName.isEmpty ? 'Account' : displayName,
        avatarUrl: avatarUrl,
      );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrototypeSubpageScaffold(
      includeShellTopBar: true,
      title: 'Edit Profile',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: PrototypePhotoUpload(
                imageFile: _photoFile,
                imageUrl: _photoFile == null ? _networkAvatarUrl : null,
                onTap: _saving ? null : _pickPhoto,
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Tap to change photo', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: _email,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
