import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Offline stand-in for widgets that render the shell top bar (unread bell dot).
class FakeNotificationsRepository extends NotificationsRepository {
  FakeNotificationsRepository()
    : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<int> unreadCount() async => 0;
}

/// Offline account source for the shell top bar avatar.
class FakeShellAccountRepository extends AccountRepository {
  FakeShellAccountRepository()
    : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<void> ensureAccountLoaded() async {}
}

/// Providers the shell top bar needs (inbox notifier + account repository).
List<SingleChildWidget> shellTopBarTestProviders() => [
  ChangeNotifierProvider<NotificationsRepository>(
    create: (_) => FakeNotificationsRepository(),
  ),
  Provider<AccountRepository>(create: (_) => FakeShellAccountRepository()),
];
