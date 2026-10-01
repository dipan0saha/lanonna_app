import 'onboarding_step.dart';

abstract final class OnboardingRoutes {
  static const ownerCarousel = '/onboarding/owner/carousel';
  static const signup = '/onboarding/signup';
  static const login = '/onboarding/login';
  static const emailVerify = '/onboarding/email-verify';
  static const completeProfile = '/onboarding/complete-profile';
  static const ownerCreateBaby = '/onboarding/owner/create-baby';
  static const ownerFirstMoment = '/onboarding/owner/first-moment';
  static const ownerInvite = '/onboarding/owner/invite';
  static const roleSelection = '/role-selection';
  static const inviteAccept = '/invite-accept';
  static const followerInvite = '/onboarding/follower/invite';
  static const coOwnerInvite = '/onboarding/coowner/invite';
  static const confirmRelationship = '/onboarding/follower/confirm-relationship';
  static const followerCarousel = '/onboarding/follower/carousel';
  static const coOwnerWelcome = '/onboarding/coowner/welcome';
  static const wrongEmail = '/onboarding/wrong-email';

  static bool isOnboardingPath(String location) {
    return location.startsWith('/onboarding') ||
        location == roleSelection ||
        location == inviteAccept;
  }

  static String pathForStep(OnboardingStep step) {
    return switch (step) {
      OnboardingStep.carousel => ownerCarousel,
      OnboardingStep.signup => signup,
      OnboardingStep.login => login,
      OnboardingStep.emailVerify => emailVerify,
      OnboardingStep.completeProfile => completeProfile,
      OnboardingStep.createBaby => ownerCreateBaby,
      OnboardingStep.firstMoment => ownerFirstMoment,
      OnboardingStep.batchInvite => ownerInvite,
      OnboardingStep.followerInvite => followerInvite,
      OnboardingStep.coOwnerInvite => coOwnerInvite,
      OnboardingStep.confirmRelationship => confirmRelationship,
      OnboardingStep.followerCarousel => followerCarousel,
      OnboardingStep.coOwnerWelcome => coOwnerWelcome,
    };
  }

  static String signupWithInvite({
    required String path,
    required String inviteToken,
    String? email,
  }) {
    final params = <String, String>{
      'path': path,
      'invite_token': inviteToken,
    };
    if (email != null && email.isNotEmpty) {
      params['email'] = email;
    }
    return '$signup?${Uri(queryParameters: params).query}';
  }

  static String loginWithInvite({
    required String path,
    required String inviteToken,
    String? email,
  }) {
    final params = <String, String>{
      'path': path,
      'invite_token': inviteToken,
    };
    if (email != null && email.isNotEmpty) {
      params['email'] = email;
    }
    return '$login?${Uri(queryParameters: params).query}';
  }
}
