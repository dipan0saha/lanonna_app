import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/validation/form_validators.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/media/cached_signed_image.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../gallery/data/gallery_repository.dart';
import '../../gallery/data/models/photo_models.dart';
import '../../gallery/domain/gallery_refresh.dart';
import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../data/calendar_repository.dart';
import 'calendar_display.dart';
import 'widgets/event_form_widgets.dart';

class EventFormPrefill {
  EventFormPrefill({
    required this.title,
    required this.description,
    this.catalogSuggestionId,
    this.initialDate,
  });

  final String title;
  final String description;
  final String? catalogSuggestionId;
  final DateTime? initialDate;
}

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({
    super.key,
    this.eventId,
    this.initialTitle,
    this.initialDescription,
    this.initialCatalogSuggestionId,
    this.initialDate,
  });

  final String? eventId;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialCatalogSuggestionId;
  final DateTime? initialDate;

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
  String? _coverPhotoPreviewUrl;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.initialTitle ?? '';
    _description.text = widget.initialDescription ?? '';
    if (widget.initialDate != null) {
      _date = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
    }
    _init();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _video.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadBaby();
    if (widget.isEdit) await _loadEvent();
  }

  Future<void> _loadBaby() async {
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final baby = await homeRepo.resolveSelectedBaby(store);
    if (mounted) setState(() => _baby = baby);
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
      detail.startsAt.toLocal().year,
      detail.startsAt.toLocal().month,
      detail.startsAt.toLocal().day,
    );
    _time = TimeOfDay(
      hour: detail.startsAt.toLocal().hour,
      minute: detail.startsAt.toLocal().minute,
    );
    _coverPhotoId = detail.coverPhotoId;
    _coverPhotoPreviewUrl = detail.coverPhotoDisplayUrl;
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickCoverPhoto() async {
    final baby = _baby;
    if (baby == null) return;
    final photos = await context.read<GalleryRepository>().listPhotos(baby.id);
    final picked = await showModalBottomSheet<({String? id, String? thumbUrl})?>(
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
                if (context.mounted) notifyGalleryDataChanged(context);
                Navigator.pop(context, (id: id, thumbUrl: null));
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('No cover photo'),
              onTap: () => Navigator.pop(context, (id: '', thumbUrl: null)),
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
                          onTap: () => Navigator.pop(
                            context,
                            (id: p.id, thumbUrl: p.thumbUrl),
                          ),
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
    setState(() {
      if (picked.id == null || picked.id!.isEmpty) {
        _coverPhotoId = null;
        _coverPhotoPreviewUrl = null;
      } else {
        _coverPhotoId = picked.id;
        _coverPhotoPreviewUrl = picked.thumbUrl;
      }
    });
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
    final title = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _title.text,
    );
    if (baby == null) {
      AppSnackBar.showAlert(context, 'Baby profile is still loading. Try again.');
      return;
    }
    if (title.isEmpty) {
      AppSnackBar.showAlert(context, 'Enter an event title to continue.');
      return;
    }
    final videoError = validateOptionalHttpUrl(_video.text);
    if (videoError != null) {
      AppSnackBar.showAlert(context, videoError);
      return;
    }
    final description = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _description.text,
    );
    final location = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _location.text,
    );
    final videoCallUrl = normalizeOptionalHttpUrl(_video.text);
    setState(() => _saving = true);
    try {
      final repo = context.read<CalendarRepository>();
      final startsAt = _startsAtLocal();
      if (widget.isEdit) {
        await repo.updateEvent(
          baby.id,
          widget.eventId!,
          title: title,
          startsAt: startsAt,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          videoCallUrl: videoCallUrl,
          coverPhotoId: _coverPhotoId,
        );
      } else {
        await repo.createEvent(
          baby.id,
          title: title,
          startsAt: startsAt,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          videoCallUrl: videoCallUrl,
          coverPhotoId: _coverPhotoId,
          catalogSuggestionId: widget.initialCatalogSuggestionId,
        );
      }
      if (mounted) {
        context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
        if (widget.isEdit) {
          context.pop();
        } else {
          context.pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startsAtLocal = _startsAtLocal();
    final pastStart = !widget.isEdit && isEventStartInPast(startsAtLocal);
    final canSave = _baby != null && !_saving;
    final saveLabel = widget.isEdit ? 'Save Changes' : 'Save Event';

    return PrototypeSubpageScaffold(
      title: widget.isEdit ? 'Edit Event' : 'New Event',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.horizontalPadding,
          0,
          AppMetrics.horizontalPadding,
          96,
        ),
        children: [
          AppLabeledTextField(
            semanticsId: 'calendar_event_title',
            label: 'Event Title',
            hint: 'e.g. Gender Reveal Party',
            kind: AppTextInputKind.prose,
            controller: _title,
          ),
          AppLabeledTextField(
            label: 'Description (optional)',
            hint: 'Add a short description…',
            kind: AppTextInputKind.prose,
            controller: _description,
            maxLines: 5,
            minLines: 3,
          ),
          PrototypeDateField(
            label: 'Date',
            value: _date,
            placeholder: 'Select a date',
            onTap: _pickDate,
          ),
          const SizedBox(height: AppMetrics.formFieldSpacing),
          PrototypeTimeField(
            label: 'Time (optional)',
            time: _time,
            placeholder: 'Select a time',
            onTap: _pickTime,
          ),
          if (pastStart)
            Padding(
              padding: const EdgeInsets.only(bottom: AppMetrics.formFieldSpacing),
              child: Text(
                'This time is in the past. The event will show on the month view but not in Upcoming.',
                style: context.textStyles.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
          AppLabeledTextField(
            label: 'Location (optional)',
            hint: "e.g. Grandma Sue's backyard",
            kind: AppTextInputKind.prose,
            controller: _location,
          ),
          AppLabeledTextField(
            label: 'Video call link (optional)',
            hint: 'Paste a Zoom / FaceTime link',
            kind: AppTextInputKind.none,
            controller: _video,
            keyboardType: TextInputType.url,
          ),
          PrototypeEventCoverUpload(
            onTap: _baby == null ? null : _pickCoverPhoto,
            previewImageUrl: _coverPhotoPreviewUrl,
            cacheKey: _coverPhotoId != null ? 'event-cover-$_coverPhotoId' : null,
          ),
          const SizedBox(height: 8),
          AppSemantics.button(
            'calendar_event_save',
            FilledButton(
              onPressed: canSave ? _save : null,
              child: Text(_saving ? 'Saving…' : saveLabel),
            ),
            label: saveLabel,
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
          ? CachedSignedImage(
              imageUrl: url,
              cacheKey: 'thumb-${photo.id}',
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            )
          : Container(
              width: 88,
              height: 88,
              color: Colors.grey.shade300,
              child: const Icon(Icons.image),
            ),
    );
  }
}
