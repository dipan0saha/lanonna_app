abstract final class AppRoutes {
  static const inviteFamily = '/invite-family';

  static String homeActivity(String babyId) => '/home/activity?babyId=$babyId';
  static const gamification = '/gamification';
}
