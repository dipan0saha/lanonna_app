/// Account summary line for the current notification digest preference.
String notificationDigestSummaryLabel(String digest) {
  switch (digest) {
    case 'daily':
      return 'Daily email summary';
    case 'weekly':
      return 'Weekly email summary';
    case 'realtime':
    default:
      return 'Real-time updates';
  }
}
