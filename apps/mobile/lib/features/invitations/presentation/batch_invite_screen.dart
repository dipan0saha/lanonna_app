import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:lanonna/l10n/app_localizations.dart';

import '../../../core/api/run_mutation.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/validation/form_validators.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../onboarding/data/onboarding_form_drafts.dart';
import '../../invitations/data/invitations_repository.dart';
import '../domain/invitation_status.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/onboarding_routes.dart';
import '../../onboarding/domain/onboarding_step.dart';
import '../../onboarding/domain/owner_onboarding_baby_resolver.dart';
import '../../onboarding/presentation/app_session.dart';
import '../../../core/domain/relationship_preset.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../../onboarding/presentation/utils/onboarding_back_navigation.dart';
import '../../onboarding/presentation/utils/owner_onboarding_baby_missing.dart';
import '../../onboarding/presentation/widgets/onboarding_buttons.dart';
import '../../onboarding/presentation/widgets/onboarding_invite_row.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_typography.dart';

enum BatchInviteMode { onboarding, fromHome }

class _InviteRowState {
  _InviteRowState({
    String name = '',
    String email = '',
    this.relationship = RelationshipPreset.initial,
  })  : nameController = TextEditingController(text: name),
        emailController = TextEditingController(text: email);

  final TextEditingController nameController;
  final TextEditingController emailController;
  RelationshipPreset relationship;
  InviteMembershipHint? membershipHint;

  void dispose() {
    nameController.dispose();
    emailController.dispose();
  }

  bool get showOwnerBadge => relationship.grantsCoOwner;

  InviteRowDraft toDraft() => InviteRowDraft(
        name: nameController.text,
        email: emailController.text,
        relationship: relationship,
      );

  /// [options] guards against a draft saved from the other invite flow.
  static _InviteRowState fromDraft(
    InviteRowDraft draft,
    List<RelationshipPreset> options,
  ) =>
      _InviteRowState(
        name: draft.name,
        email: draft.email,
        relationship: options.contains(draft.relationship)
            ? draft.relationship
            : RelationshipPreset.initial,
      );
}

class BatchInviteScreen extends StatefulWidget {
  const BatchInviteScreen({super.key, required this.mode});

  final BatchInviteMode mode;

  @override
  State<BatchInviteScreen> createState() => _BatchInviteScreenState();
}

class _BatchInviteScreenState extends State<BatchInviteScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  late final List<RelationshipPreset> _relationshipOptions;
  final _rows = <_InviteRowState>[];
  var _synced = false;
  var _busy = false;
  String? _error;

  bool get _isOnboarding => widget.mode == BatchInviteMode.onboarding;

  @override
  void initState() {
    super.initState();
    _relationshipOptions =
        _isOnboarding ? RelationshipPreset.onboardingOptions : RelationshipPreset.appOptions;
    _rows.add(_InviteRowState());
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _persistDraft() async {
    if (!_isOnboarding || !mounted) return;
    await context.read<OnboardingCoordinator>().saveBatchInviteDraft(
          BatchInviteDraft(rows: _rows.map((r) => r.toDraft()).toList()),
        );
  }

  Future<String?> _resolveBabyId() async {
    if (_isOnboarding) {
      final coordinator = context.read<OnboardingCoordinator>();
      final session = context.read<AppSession>();
      return OwnerOnboardingBabyResolver.resolve(
        coordinator: coordinator,
        readStatus: () => session.status,
        refreshStatus: session.refreshFromApi,
      );
    }
    final baby = await context.read<HomeRepository>().resolveOwnerBaby(
          context.read<SelectedBabyStore>(),
        );
    return baby?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced || !_isOnboarding) return;
    _synced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OnboardingCoordinator>().setStep(OnboardingStep.batchInvite);
      final draft = context.read<OnboardingCoordinator>().batchInviteDraft;
      if (draft != null) {
        for (final row in _rows) {
          row.dispose();
        }
        _rows
          ..clear()
          ..addAll(
            draft.rows.map(
              (d) => _InviteRowState.fromDraft(d, _relationshipOptions),
            ),
          );
        if (_rows.isEmpty) {
          _rows.add(_InviteRowState());
        }
        setState(() {});
      }
    });
  }

  void _addRow() {
    setState(() => _rows.add(_InviteRowState()));
    _persistDraft();
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
    _persistDraft();
  }

  Future<void> _checkMembershipForRow(int index) async {
    final babyId = await _resolveBabyId();
    final email = _rows[index].emailController.text.trim();
    if (babyId == null || email.isEmpty || validateEmail(AppLocalizations.of(context)!, email) != null) {
      setState(() => _rows[index].membershipHint = null);
      return;
    }
    if (!mounted) return;
    try {
      final result = await context.read<InvitationsRepository>().checkMembership(
            babyId,
            email,
          );
      if (!mounted) return;
      setState(() {
        _rows[index].membershipHint = InviteMembershipHint.fromCheck(
          isMember: result.isMember,
          hasPendingInvite: result.hasPendingInvite,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _rows[index].membershipHint = null);
    }
  }

  List<Map<String, dynamic>> _collectInvitesToSend() {
    final invites = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final email = row.emailController.text.trim();
      if (email.isEmpty) continue;
      if (validateEmail(AppLocalizations.of(context)!, email) != null) continue;
      if (row.membershipHint != null) continue;
      invites.add({
        'email': email,
        'role': row.showOwnerBadge ? 'owner' : 'follower',
        'relationship_label': row.relationship.membershipLabel,
      });
    }
    return invites;
  }

  String? _validateBeforeSend(AppLocalizations l10n) {
    var sawEmail = false;
    var sawInvalid = false;
    for (final row in _rows) {
      final email = row.emailController.text.trim();
      if (email.isEmpty) continue;
      sawEmail = true;
      if (validateEmail(AppLocalizations.of(context)!, email) != null) {
        sawInvalid = true;
        continue;
      }
      if (row.membershipHint != null) continue;
      return null;
    }
    if (!sawEmail) {
      return l10n.batchInviteAddEmailToSend;
    }
    if (sawInvalid) {
      return l10n.batchInviteInvalidEmails;
    }
    return l10n.batchInviteNoNewInvites;
  }

  Future<void> _finish({required bool sendInvites}) async {
    final session = context.read<AppSession>();
    final babyId = await _resolveBabyId();
    if (babyId == null) {
      if (!mounted) return;
      handleOwnerOnboardingBabyMissing(
        context,
        session,
        setError: (message) => setState(() => _error = message),
      );
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (sendInvites) {
        final validationError = _validateBeforeSend(l10n);
        final invites = _collectInvitesToSend();
        if (invites.isEmpty) {
          setState(
            () => _error = validationError ?? l10n.batchInviteNoInvitesToSend,
          );
          return;
        }
      }
      if (!mounted) return;
      final ok = await runMutation(context, () async {
        await _persistDraft();
        if (sendInvites) {
          final invites = _collectInvitesToSend();
          final response = await context
              .read<OnboardingRepository>()
              .sendBatchInvites(babyId, invites);
          if (!mounted) return;
          if (response.emailQueueFailedCount > 0) {
            AppSnackBar.showAlert(
              context,
              l10n.batchInviteEmailQueueFailed(response.emailQueueFailedCount),
            );
          }
        }
      });
      if (!ok || !mounted) return;
      if (_isOnboarding) {
        await context.read<AuthRepository>().refreshSessionClaims();
        if (!mounted) return;
        await context.read<OnboardingCoordinator>().completeOnboarding();
        if (!mounted) return;
        await context.read<AppSession>().refreshFromApi();
        if (mounted) context.go('/home');
      } else {
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _coOwnerHintBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sageTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _isOnboarding
            ? AppLocalizations.of(context)!.batchInviteCoOwnerHintOnboarding
            : AppLocalizations.of(context)!.batchInviteCoOwnerHintManage,
        style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.hintOnSage),
      ),
    );
  }

  Widget _inviteRows() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _rows.length; i++)
          OnboardingInviteRow(
            nameController: _rows[i].nameController,
            emailController: _rows[i].emailController,
            relationship: _rows[i].relationship,
            relationshipOptions: _relationshipOptions,
            showOwnerBadge: _rows[i].showOwnerBadge,
            membershipHint: _rows[i].membershipHint?.label(l10n),
            onRelationshipChanged: (v) {
              setState(() => _rows[i].relationship = v);
              _persistDraft();
            },
            onRemove: _rows.length > 1 ? () => _removeRow(i) : null,
            onFieldChanged: _persistDraft,
            onEmailEditingComplete: () => _checkMembershipForRow(i),
          ),
        PrototypeAddAnotherButton(
          onTap: _busy ? () {} : _addRow,
          label: _isOnboarding ? l10n.actionAddAnother : l10n.invitationsAddAnotherPerson,
        ),
        OnboardingPrimaryButton(
          semanticsId: _isOnboarding ? null : 'batch_invite_send',
          label: l10n.actionSendInvites,
          isLoading: _busy,
          onPressed: _busy ? null : () => _finish(sendInvites: true),
        ),
        if (_isOnboarding)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: GestureDetector(
                onTap: _busy ? null : () => _finish(sendInvites: false),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Text(
                    l10n.actionSkipNow,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 8),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _onboardingBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        OnboardingHeadline(
          l10n.invitationsInviteFamilyFriends,
          key: Key('onboarding_invite_title'),
        ),
        const SizedBox(height: 8),
        OnboardingSupportText(
          l10n.invitationsAddThePeopleYouWant,
        ),
        const SizedBox(height: 18),
        _inviteRows(),
      ],
    );
  }

  Widget _fromHomeBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        8,
        AppMetrics.horizontalPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingSupportText(
            l10n.invitationsWellSendEachPersonA,
          ),
          const SizedBox(height: 12),
          _coOwnerHintBanner(),
          _inviteRows(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnboarding) {
      return OnboardingScaffold(
        pinBottomCta: false,
        showBack: true,
        onBack: () => goOnboardingBack(
          context,
          step: OnboardingStep.firstMoment,
          route: OnboardingRoutes.ownerFirstMoment,
          persist: _persistDraft,
        ),
        body: SingleChildScrollView(child: _onboardingBody()),
      );
    }
    return PrototypeSubpageScaffold(
      title: l10n.actionInviteFriends,
      body: SingleChildScrollView(child: _fromHomeBody()),
    );
  }
}
