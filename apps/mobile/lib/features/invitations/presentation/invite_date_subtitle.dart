import '../data/models/invitation_preview.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatUsDate(String? raw) {
  final dt = raw == null ? null : DateTime.tryParse(raw);
  if (dt == null) return '';
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String inviteBabyDateSubtitle(InvitationPreview preview) {
  if (preview.isBorn) {
    final formatted = _formatUsDate(preview.actualBirthDate);
    return formatted.isEmpty ? 'Already here' : 'Born $formatted';
  }
  final formatted = _formatUsDate(preview.expectedBirthDate);
  return formatted.isEmpty ? 'On the way' : 'Arriving $formatted';
}

String inviteBabyHeroTitle(InvitationPreview preview) {
  final name = preview.babyName ?? 'Baby';
  if (preview.isBorn) return name;
  return 'Waiting for $name';
}
