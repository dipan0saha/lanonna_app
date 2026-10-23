import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_path.dart';

void main() {
  test('takeLoginPrefillEmail returns value once', () {
    final state = InviteFlowState();
    state.setLoginPrefillEmail('a@b.com');
    expect(state.takeLoginPrefillEmail(), 'a@b.com');
    expect(state.takeLoginPrefillEmail(), isNull);
  });

  test('takeInviteResume returns token, path, and preview once', () {
    final state = InviteFlowState();
    state.setInviteResume(
      token: 'tok',
      path: OnboardingPath.follower,
      previewJson: '{"status":"pending"}',
    );
    final resume = state.takeInviteResume();
    expect(resume?.token, 'tok');
    expect(resume?.path, OnboardingPath.follower);
    expect(resume?.previewJson, '{"status":"pending"}');
    expect(state.takeInviteResume(), isNull);
  });

  test('clear resets mismatch and prefill', () {
    final state = InviteFlowState();
    state.setEmailMismatch(inviteeEmail: 'a', signedInEmail: 'b');
    state.setSignupPrefillEmail('c@d.com');
    state.clear();
    expect(state.emailMismatch, isNull);
    expect(state.takeSignupPrefillEmail(), isNull);
  });
}
