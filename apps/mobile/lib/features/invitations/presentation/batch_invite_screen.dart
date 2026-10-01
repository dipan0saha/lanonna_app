import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/validation/form_validators.dart';
import '../../home/data/selected_baby_store.dart';
import '../../onboarding/data/onboarding_form_drafts.dart';
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
import '../../onboarding/presentation/widgets/onboarding_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_typography.dart';

enum BatchInviteMode { onboarding, fromHome }

class _InviteRowState {
  _InviteRowState({
    String name = '',
    String email = '',
    InviteRelationshipOption? relationship,
  })  : nameController = TextEditingController(text: name),
        emailController = TextEditingController(text: email),
        relationship = relationship ?? kInviteRelationshipOptions[2];

  final TextEditingController nameController;
  final TextEditingController emailController;
  InviteRelationshipOption relationship;

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

  static _InviteRowState fromDraft(InviteRowDraft draft) => _InviteRowState(
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
  final _rows = <_InviteRowState>[_InviteRowState()];
  var _synced = false;
  var _busy = false;
  String? _error;

  bool get _isOnboarding => widget.mode == BatchInviteMode.onboarding;

  @override
  void dispose() {
    if (_isOnboarding) {
      _persistDraft();
    }
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _persistDraft() async {
    if (!_isOnboarding) return;
    await context.read<OnboardingCoordinator>().saveBatchInviteDraft(
      BatchInviteDraft(rows: _rows.map((r) => r.toDraft()).toList()),
    );
  }

  String? _resolveBabyId() {
    if (_isOnboarding) {
      return context.read<OnboardingCoordinator>().createdBabyId;
    }
    return context.read<SelectedBabyStore>().selectedBabyId;
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
          ..addAll(draft.rows.map(_InviteRowState.fromDraft));
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

  Future<void> _finish({required bool sendInvites}) async {
    final babyId = _resolveBabyId();
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
        final invites = <Map<String, dynamic>>[];
        for (final row in _rows) {
          final email = row.emailController.text.trim();
          if (email.isEmpty) continue;
          if (validateEmail(email) != null) continue;
          invites.add({
            'email': email,
            'role': row.showOwnerBadge ? 'owner' : 'follower',
            'relationship_label': row.relationship.membershipLabel,
          });
        }
        if (invites.isNotEmpty) {
          await context.read<OnboardingRepository>().sendBatchInvites(babyId, invites);
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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: _isOnboarding
          ? () => goOnboardingBack(
                context,
                step: OnboardingStep.firstMoment,
                route: OnboardingRoutes.ownerFirstMoment,
                persist: _persistDraft,
              )
          : () => context.pop(),
      body: Column(
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
          for (var i = 0; i < _rows.length; i++)
            OnboardingInviteRow(
              nameController: _rows[i].nameController,
              emailController: _rows[i].emailController,
              relationship: _rows[i].relationship,
              showOwnerBadge: _rows[i].showOwnerBadge,
              onRelationshipChanged: (v) {
                setState(() => _rows[i].relationship = v);
                _persistDraft();
              },
              onRemove: _rows.length > 1 ? () => _removeRow(i) : null,
              onFieldChanged: _persistDraft,
            ),
          PrototypeAddAnotherButton(onTap: _busy ? () {} : _addRow),
          OnboardingPrimaryButton(
            label: 'Send Invites',
            isLoading: _busy,
            onPressed: _busy ? null : () => _finish(sendInvites: true),
          ),
          if (_isOnboarding)
            Center(
              child: GestureDetector(
                onTap: _busy ? null : () => _finish(sendInvites: false),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 8),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
