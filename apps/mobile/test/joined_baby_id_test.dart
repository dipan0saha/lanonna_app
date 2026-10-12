import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/onboarding/presentation/utils/invite_flow_navigation.dart';

void main() {
  test('joined baby prefers the accept result', () {
    expect(
      joinedBabyIdFromAccept(
        acceptedBabyId: 'from-accept',
        invitedBabyId: 'from-coordinator',
        previewBabyId: 'from-preview',
      ),
      'from-accept',
    );
  });

  test('joined baby falls back to the coordinator then the preview', () {
    expect(
      joinedBabyIdFromAccept(
        acceptedBabyId: '',
        invitedBabyId: 'from-coordinator',
        previewBabyId: 'from-preview',
      ),
      'from-coordinator',
    );
    expect(
      joinedBabyIdFromAccept(
        acceptedBabyId: null,
        invitedBabyId: null,
        previewBabyId: 'from-preview',
      ),
      'from-preview',
    );
    expect(
      joinedBabyIdFromAccept(
        acceptedBabyId: null,
        invitedBabyId: null,
        previewBabyId: null,
      ),
      isNull,
    );
  });
}
