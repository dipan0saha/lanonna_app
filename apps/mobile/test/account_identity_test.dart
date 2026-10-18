import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/account/data/account_identity_store.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends ApiClient {
  _Api() : super(idTokenProvider: () async => 't');

  var offline = false;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    if (offline) throw Exception('offline');
    if (path == '/v1/me/account') {
      return {
        'profile': {
          'display_name': 'Dana Lee',
          'email': 'dana@test.invalid',
          'avatar_url': 'https://example.invalid/a.jpg',
        },
        'babies': [],
      };
    }
    throw UnimplementedError(path);
  }
}

void main() {
  late SharedPreferences prefs;
  var uid = 'u1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    uid = 'u1';
  });

  AccountRepository repo(_Api api) => AccountRepository(
    api,
    identityStore: AccountIdentityStore(prefs),
    currentUserId: () => uid,
  );

  test('the last loaded identity survives an offline cold start', () async {
    await repo(_Api()).ensureAccountLoaded();
    await Future<void>.delayed(Duration.zero);

    // New process, offline: the profile cannot load.
    final offline = repo(_Api()..offline = true);
    await expectLater(offline.ensureAccountLoaded(), throwsException);
    final identity = offline.identity;
    expect(identity?.displayName, 'Dana Lee');
    expect(identity?.email, 'dana@test.invalid');
    expect(identity?.avatarUrl, 'https://example.invalid/a.jpg');
  });

  test('another account never sees the identity', () async {
    await repo(_Api()).ensureAccountLoaded();
    await Future<void>.delayed(Duration.zero);
    uid = 'u2';
    expect(repo(_Api()..offline = true).identity, isNull);
  });

  test('sign-out clears the stored identity', () async {
    final r = repo(_Api());
    await r.ensureAccountLoaded();
    r.clearCachedAccount();
    await Future<void>.delayed(Duration.zero);
    expect(r.identity, isNull);
    expect(repo(_Api()..offline = true).identity, isNull);
  });

  test('the loaded profile wins over the stored one', () async {
    await AccountIdentityStore(
      prefs,
    ).remember('u1', const AccountIdentity(displayName: 'Old Name'));
    final r = repo(_Api());
    await r.ensureAccountLoaded();
    expect(r.identity?.displayName, 'Dana Lee');
  });
}
