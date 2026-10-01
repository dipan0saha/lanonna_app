import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../gallery/data/gallery_repository.dart';
import '../../gallery/data/models/photo_models.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../onboarding/data/models/baby_summary.dart';
import '../data/calendar_repository.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({
    super.key,
    this.eventId,
    this.initialTitle,
    this.initialDescription,
  });

  final String? eventId;
  final String? initialTitle;
  final String? initialDescription;

  bool get isEdit => eventId != null;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _video = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  BabySummary? _baby;
  String? _coverPhotoId;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.initialTitle ?? '';
    _description.text = widget.initialDescription ?? '';
    _init();
  }

  Future<void> _init() async {
    await _loadBaby();
    if (widget.isEdit) await _loadEvent();
  }

  Future<void> _loadBaby() async {
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final baby = await homeRepo.resolveSelectedBaby(store);
    setState(() => _baby = baby);
  }

  Future<void> _loadEvent() async {
    final baby = _baby;
    final id = widget.eventId;
    if (baby == null || id == null) return;
    final detail =
        await context.read<CalendarRepository>().fetchEvent(baby.id, id);
    _title.text = detail.title;
    _description.text = detail.description ?? '';
    _location.text = detail.location ?? '';
    _video.text = detail.videoCallUrl ?? '';
    _date = DateTime(
      detail.startsAt.year,
      detail.startsAt.month,
      detail.startsAt.day,
    );
    _time = TimeOfDay(
      hour: detail.startsAt.hour,
      minute: detail.startsAt.minute,
    );
    _coverPhotoId = detail.coverPhotoId;
    setState(() {});
  }

  Future<void> _pickCoverPhoto() async {
    final baby = _baby;
    if (baby == null) return;
    final photos = await context.read<GalleryRepository>().listPhotos(baby.id);
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Upload new photo'),
              onTap: () async {
                final file = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (file == null) {
                  Navigator.pop(context);
                  return;
                }
                final id = await DisplayPhotoUpload(context.read<ApiClient>())
                    .uploadGalleryPhoto(
                  babyProfileId: baby.id,
                  imageFile: File(file.path),
                );
                Navigator.pop(context, id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('No cover photo'),
              onTap: () => Navigator.pop(context, ''),
            ),
            if (photos.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final p in photos)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, p.id),
                          child: _CoverThumb(photo: p),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _coverPhotoId = picked.isEmpty ? null : picked);
  }

  DateTime _startsAtLocal() {
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
  }

  Future<void> _save() async {
    final baby = _baby;
    if (baby == null || _title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<CalendarRepository>();
      final startsAt = _startsAtLocal();
      if (widget.isEdit) {
        await repo.updateEvent(
          baby.id,
          widget.eventId!,
          title: _title.text.trim(),
          startsAt: startsAt,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          videoCallUrl: _video.text.trim().isEmpty ? null : _video.text.trim(),
          coverPhotoId: _coverPhotoId,
        );
      } else {
        await repo.createEvent(
          baby.id,
          title: _title.text.trim(),
          startsAt: startsAt,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          videoCallUrl: _video.text.trim().isEmpty ? null : _video.text.trim(),
          coverPhotoId: _coverPhotoId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit event' : 'New event'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 3,
          ),
          ListTile(
            title: const Text('Date'),
            subtitle: Text(
              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          ListTile(
            title: const Text('Time'),
            subtitle: Text(_time.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (picked != null) setState(() => _time = picked);
            },
          ),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          TextField(
            controller: _video,
            decoration: const InputDecoration(labelText: 'Video call link'),
          ),
          ListTile(
            title: const Text('Cover photo'),
            subtitle: Text(
              _coverPhotoId == null ? 'None' : 'Photo selected',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickCoverPhoto,
          ),
        ],
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.photo});

  final PhotoSummary photo;

  @override
  Widget build(BuildContext context) {
    final url = photo.thumbUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url != null
          ? Image.network(url, width: 88, height: 88, fit: BoxFit.cover)
          : Container(
              width: 88,
              height: 88,
              color: Colors.grey.shade300,
              child: const Icon(Icons.image),
            ),
    );
  }
}
