import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/validation/form_validators.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../onboarding/data/onboarding_form_drafts.dart';
import '../../invitations/data/invitations_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/onboarding_routes.dart';
import '../../onboarding/domain/onboarding_step.dart';
import '../../onboarding/presentation/app_session.dart';
import '../../onboarding/presentation/models/invite_relationship_option.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../../onboarding/presentation/utils/onboarding_back_navigation.dart';
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
    required List<InviteRelationshipOption> relationshipOptions,
    String name = '',
    String email = '',
    InviteRelationshipOption? relationship,
  })  : nameController = TextEditingController(text: name),
        emailController = TextEditingController(text: email),
        relationship = relationship ?? relationshipOptions[2];

  final TextEditingController nameController;
  final TextEditingController emailController;
  InviteRelationshipOption relationship;
  String? membershipHint;

  void dispose() {
    nameController.dispose();
    emailController.dispose();
  }

  bool get showOwnerBadge => relationship.grantsCoOwner;

  InviteRowDraft toDraft() => InviteRowDraft(
        name: nameController.text,
        email: emailController.text,
        relationshipPickerLabel: relationship.pickerLabel,
      );

  static _InviteRowState fromDraft(
    InviteRowDraft draft,
    List<InviteRelationshipOption> relationshipOptions,
  ) =>
      _InviteRowState(
        relationshipOptions: relationshipOptions,
        name: draft.name,
        email: draft.email,
        relationship: inviteRelationshipByPickerLabel(draft.relationshipPickerLabel),
      );
}

class BatchInviteScreen extends StatefulWidget {
  const BatchInviteScreen({super.key, required this.mode});

  final BatchInviteMode mode;

  @override
  State<BatchInviteScreen> createState() => _BatchInviteScreenState();
}

class _BatchInviteScreenState extends State<BatchInviteScreen> {
  late final List<InviteRelationshipOption> _relationshipOptions;
  final _rows = <_InviteRowState>[];
  var _synced = false;
  var _busy = false;
  String? _error;

  bool get _isOnboarding => widget.mode == BatchInviteMode.onboarding;

  @override
  void initState() {
    super.initState();
    _relationshipOptions =
        _isOnboarding ? kInviteRelationshipOptions : kAppBatchInviteRelationshipOptions;
    _rows.add(_InviteRowState(relationshipOptions: _relationshipOptions));
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
      return context.read<OnboardingCoordinator>().createdBabyId;
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
          _rows.add(_InviteRowState(relationshipOptions: _relationshipOptions));
        }
        setState(() {});
      }
    });
  }

  void _addRow() {
    setState(() => _rows.add(_InviteRowState(relationshipOptions: _relationshipOptions)));
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
    if (babyId == null || email.isEmpty || validateEmail(email) != null) {
      setState(() => _rows[index].membershipHint = null);
      return;
    }
    try {
      final result = await context.read<InvitationsRepository>().checkMembership(
            babyId,
            email,
          );
      if (!mounted) return;
      setState(() {
        if (result.isMember) {
          _rows[index].membershipHint = 'Already on the family';
        } else if (result.hasPendingInvite) {
          _rows[index].membershipHint = 'Invitation already pending';
        } else {
          _rows[index].membershipHint = null;
        }
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
      if (validateEmail(email) != null) continue;
      if (row.membershipHint == 'Already on the family') continue;
      if (row.membershipHint == 'Invitation already pending') continue;
      invites.add({
        'email': email,
        'role': row.showOwnerBadge ? 'owner' : 'follower',
        'relationship_label': row.relationship.membershipLabel,
      });
    }
    return invites;
  }

  String? _validateBeforeSend() {
    var sawEmail = false;
    var sawInvalid = false;
    for (final row in _rows) {
      final email = row.emailController.text.trim();
      if (email.isEmpty) continue;
      sawEmail = true;
      if (validateEmail(email) != null) {
        sawInvalid = true;
        continue;
      }
      if (row.membershipHint == 'Already on the family') continue;
      if (row.membershipHint == 'Invitation already pending') continue;
      return null;
    }
    if (!sawEmail) {
      return 'Add at least one email address to send invites.';
    }
    if (sawInvalid) {
      return 'Enter a valid email for each invite row.';
    }
    return 'No new invites to send for the emails entered.';
  }

  Future<void> _finish({required bool sendInvites}) async {
    final babyId = await _resolveBabyId();
    if (babyId == null) {
      setState(() => _error = 'Baby profile missing.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _persistDraft();
      if (sendInvites) {
        final validationError = _validateBeforeSend();
        final invites = _collectInvitesToSend();
        if (invites.isEmpty) {
          setState(() => _error = validationError ?? 'No invites to send.');
          return;
        }
        final response = await context
            .read<OnboardingRepository>()
            .sendBatchInvites(babyId, invites);
        if (mounted && response.emailQueueFailedCount > 0) {
          final n = response.emailQueueFailedCount;
          AppSnackBar.showAlert(
            context,
            n == 1
                ? 'One invite was saved but the email could not be sent. Check Manage followers.'
                : '$n invites were saved but emails could not be sent. Check Manage followers.',
          );
        }
      }
      if (_isOnboarding) {
        await context.read<AuthRepository>().refreshSessionClaims();
        await context.read<OnboardingCoordinator>().completeOnboarding();
        await context.read<AppSession>().refreshFromApi();
        if (mounted) context.go('/home');
      } else if (mounted) {
        context.pop();
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
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
            ? 'Selecting Wife or Husband makes that person a co-owner with the same edit access as you.'
            : '💡 Selecting "Mother" or "Father" makes that person a co-owner of this baby profile, with the same edit access as you.',
        style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF3a5a2e)),
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
            membershipHint: _rows[i].membershipHint,
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
          label: _isOnboarding ? 'Add another' : 'Add another person',
        ),
        OnboardingPrimaryButton(
          semanticsId: _isOnboarding ? null : 'batch_invite_send',
          label: 'Send Invites',
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Text(
                    'Skip for now',
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
        const OnboardingHeadline(
          'Invite family & friends',
          key: Key('onboarding_invite_title'),
        ),
        const SizedBox(height: 8),
        const OnboardingSupportText(
          'Add the people you want to share this with. You can always invite more later.',
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
          const OnboardingSupportText(
            "We'll send each person a private link. It expires in 7 days.",
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
      title: 'Invite Family & Friends',
      body: SingleChildScrollView(child: _fromHomeBody()),
    );
  }
}
