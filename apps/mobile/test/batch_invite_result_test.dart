import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/invitations/data/batch_invite_result.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

void main() {
  test('counts rows skipped by the owner limit and failed email queues', () {
    final response = BatchInviteResponse.fromJson({
      'results': [
        {'email': 'a@test.com', 'status': 'created', 'invitation_id': 'i1'},
        {'email': 'b@test.com', 'status': 'skipped_max_owners'},
        {'email': 'c@test.com', 'status': 'email_queue_failed'},
        {'email': 'd@test.com', 'status': 'from_a_newer_server'},
      ],
    });
    expect(response.results[1].status, InviteRowStatus.skippedMaxOwners);
    expect(response.results[3].status, isNull);
    expect(response.maxOwnersSkippedCount, 1);
    expect(response.emailQueueFailedCount, 1);
  });

  test('owner-limit alert copy', () {
    final l10n = AppLocalizationsEn();
    expect(
      l10n.batchInviteMaxOwnersSkipped(1),
      startsWith('1 co-owner invite was not sent'),
    );
    expect(
      l10n.batchInviteMaxOwnersSkipped(2),
      startsWith('2 co-owner invites were not sent'),
    );
  });
}
