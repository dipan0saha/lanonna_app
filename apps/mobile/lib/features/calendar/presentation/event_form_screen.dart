import 'package:flutter/material.dart';

import '../../../core/widgets/app_modal_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/validation/form_validators.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/media/photo_selection.dart';
import '../../../core/media/pick_display_photo.dart';
import '../../../core/widgets/photo_selection_preview.dart';
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
import '../../../core/router/subpage_navigation.dart';
import '../domain/calendar_routes.dart';
import 'widgets/event_form_widgets.dart';
import '../../../l10n/app_localizations.dart';

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
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _video = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  BabySummary? _baby;
  PhotoSelection _cover = const PhotoSelection.none();
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
    if (!mounted) return;
    if (baby != null && baby.role != 'owner') {
      AppSnackBar.showAlert(
        context,
        l10n.calendarOnlyOwnersCanCreateOr,
      );
      popOrGo(context, CalendarRoutes.calendar);
      return;
    }
    setState(() => _baby = baby);
  }

  /// The cover's signed read URL expired: fetch a fresh one for the same
  /// photo without touching anything else the user has edited.
  Future<void> _refreshCoverPreview() async {
    final baby = _baby;
    final photoId = _cover.remoteRef;
    if (baby == null || photoId == null || _cover.localFile != null) return;
    try {
      final detail = await context.read<GalleryRepository>().fetchPhoto(
        baby.id,
        photoId,
      );
      if (!mounted || _cover.remoteRef != photoId) return;
      setState(() {
        _cover = _cover.withPreviewUrl(detail.thumbUrl ?? detail.displayUrl);
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(l10n, e));
      }
    }
  }

  Future<void> _loadEvent() async {
    final baby = _baby;
    final id = widget.eventId;
    if (baby == null || id == null) return;
    final detail = await context.read<CalendarRepository>().fetchEvent(
      baby.id,
      id,
    );
    _title.text = detail.title;
    _description.text = detail.description ?? '';
    _location.text = detail.location ?? '';
    _video.text = detail.videoCallUrl ?? '';
    _date = DateTime(
      eventWallTime(detail.startsAt).year,
      eventWallTime(detail.startsAt).month,
      eventWallTime(detail.startsAt).day,
    );
    _time = TimeOfDay(
      hour: eventWallTime(detail.startsAt).hour,
      minute: eventWallTime(detail.startsAt).minute,
    );
    _cover = PhotoSelection.fromStored(
      detail.coverPhotoId,
      previewUrl: detail.coverPhotoDisplayUrl,
    );
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
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  /// Lets the owner pick a new photo from the device, reuse a gallery photo,
  /// or remove the cover. Nothing is uploaded here: a new photo previews
  /// immediately and uploads when the event is saved (same as every other
  /// photo form).
  Future<void> _pickCoverPhoto() async {
    final baby = _baby;
    if (baby == null || _saving) return;
    var photos = const <PhotoSummary>[];
    try {
      final page = await context.read<GalleryRepository>().listPhotosPage(
        baby.id,
        limit: 40,
      );
      photos = page.items;
    } catch (e) {
      // The device picker and "No cover photo" still work without the list.
      if (mounted) AppSnackBar.showAlert(context, apiErrorMessage(l10n, e));
    }
    if (!mounted) return;
    final picked = await showAppModalSheet<PhotoSelection>(
      context: context,
      title: l10n.fieldCoverPhoto,
      bodyBuilder: (context) => _CoverPhotoSheetBody(photos: photos),
    );
    if (picked == null || !mounted) return;
    setState(() => _cover = picked);
  }

  /// Uploads a newly picked cover so the event can reference it. Marks the
  /// selection uploaded, so retrying a failed save does not upload twice.
  Future<String?> _coverPhotoIdForSave(String babyId) async {
    final file = _cover.localFile;
    if (!_cover.needsUpload || file == null) return _cover.remoteRef;
    final photoId = await context.read<GalleryRepository>().uploadPhoto(
      babyId,
      file,
    );
    if (mounted) {
      setState(() => _cover = _cover.uploaded(photoId));
      notifyGalleryDataChanged(context);
    }
    return photoId;
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
      AppSnackBar.showAlert(
        context,
        l10n.calendarBabyProfileIsStillLoading,
      );
      return;
    }
    if (title.isEmpty) {
      AppSnackBar.showAlert(context, l10n.calendarEnterAnEventTitleTo);
      return;
    }
    final videoError = validateOptionalHttpUrl(AppLocalizations.of(context)!, _video.text);
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
      final coverPhotoId = await _coverPhotoIdForSave(baby.id);
      if (!mounted) return;
      if (widget.isEdit) {
        await repo.updateEvent(
          baby.id,
          widget.eventId!,
          title: title,
          startsAt: startsAt,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          videoCallUrl: videoCallUrl,
          coverPhotoId: coverPhotoId,
        );
      } else {
        await repo.createEvent(
          baby.id,
          title: title,
          startsAt: startsAt,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          videoCallUrl: videoCallUrl,
          coverPhotoId: coverPhotoId,
          catalogSuggestionId: widget.initialCatalogSuggestionId,
        );
      }
      if (mounted) {
        context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(l10n, e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final startsAtLocal = _startsAtLocal();
    final pastStart = !widget.isEdit && isEventStartInPast(startsAtLocal);
    final canSave = _baby != null && !_saving;
    final saveLabel = widget.isEdit ? l10n.calendarSaveChanges : l10n.calendarSaveEvent;

    return PrototypeSubpageScaffold(
      title: widget.isEdit ? l10n.calendarEditEvent : l10n.calendarNewEvent,
      body: ListView(
        padding: AppMetrics.subpageFormScrollPadding,
        children: [
          AppLabeledTextField(
            semanticsId: 'calendar_event_title',
            label: l10n.fieldEventTitle,
            hint: l10n.labelEGGenderRevealParty,
            kind: AppTextInputKind.prose,
            controller: _title,
          ),
          AppLabeledTextField(
            label: l10n.fieldDescriptionOptional,
            hint: l10n.actionAddShortDescription,
            kind: AppTextInputKind.prose,
            controller: _description,
            maxLines: 5,
            minLines: 3,
          ),
          PrototypeDateField(
            label: l10n.fieldDate,
            value: _date,
            placeholder: l10n.fieldSelectDate,
            onTap: _pickDate,
          ),
          const SizedBox(height: AppMetrics.formFieldSpacing),
          PrototypeTimeField(
            label: l10n.fieldTimeOptional,
            time: _time,
            placeholder: l10n.fieldSelectTime,
            onTap: _pickTime,
          ),
          if (pastStart)
            Padding(
              padding: const EdgeInsets.only(top: AppMetrics.fieldLabelGap),
              child: Text(
                l10n.messageStartTime,
                style: context.textStyles.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
          const SizedBox(height: AppMetrics.formFieldSpacing),
          AppLabeledTextField(
            label: l10n.fieldLocationOptional,
            hint: l10n.labelEGGrandmaSueSBackyard,
            kind: AppTextInputKind.prose,
            controller: _location,
          ),
          AppLabeledTextField(
            label: l10n.fieldVideoCallLinkOptional,
            hint: l10n.hintPasteZoomFacetimeLink,
            kind: AppTextInputKind.none,
            controller: _video,
            keyboardType: TextInputType.url,
          ),
          PrototypeEventCoverUpload(
            selection: _cover,
            onTap: _baby == null || _saving ? null : _pickCoverPhoto,
            busy: _saving && _cover.needsUpload,
            onSignedUrlError: _refreshCoverPreview,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSemantics.button(
            'calendar_event_save',
            FilledButton(
              onPressed: canSave ? _save : null,
              child: Text(_saving ? l10n.notificationPrefsSaving : saveLabel),
            ),
            label: saveLabel,
          ),
        ],
      ),
    );
  }
}

/// Cover sheet: pick from the device, remove the cover, or reuse a gallery
/// photo. Pops the chosen [PhotoSelection]; a cancelled device picker keeps
/// the sheet open.
class _CoverPhotoSheetBody extends StatelessWidget {
  const _CoverPhotoSheetBody({required this.photos});

  final List<PhotoSummary> photos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.eventCoverUploadNew),
            onTap: () async {
              final file = await pickDisplayPhoto();
              if (file == null || !context.mounted) return;
              Navigator.pop(context, PhotoSelection.local(file));
            },
          ),
          ListTile(
            leading: const Icon(Icons.clear),
            title: Text(l10n.eventCoverNone),
            onTap: () => Navigator.pop(context, const PhotoSelection.none()),
          ),
          if (photos.isNotEmpty)
            SizedBox(
              height:
                  AppMetrics.photoSheetThumbSize + 2 * AppMetrics.photoSheetThumbGap,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in photos)
                    Padding(
                      padding: const EdgeInsets.all(AppMetrics.photoSheetThumbGap),
                      child: InkWell(
                        onTap: () => Navigator.pop(
                          context,
                          PhotoSelection.remote(ref: p.id, previewUrl: p.thumbUrl),
                        ),
                        child: PhotoSelectionPreview(
                          selection: PhotoSelection.remote(
                            ref: p.id,
                            previewUrl: p.thumbUrl,
                          ),
                          width: AppMetrics.photoSheetThumbSize,
                          height: AppMetrics.photoSheetThumbSize,
                          borderRadius: AppMetrics.photoSheetThumbRadius,
                          framed: false,
                          placeholderIcon: Icons.image_outlined,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
