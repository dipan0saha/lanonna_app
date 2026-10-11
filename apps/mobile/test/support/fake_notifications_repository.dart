import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';

/// Offline stand-in for widgets that render the shell top bar (unread bell dot).
class FakeNotificationsRepository extends NotificationsRepository {
  FakeNotificationsRepository()
      : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<int> unreadCount() async => 0;
}
