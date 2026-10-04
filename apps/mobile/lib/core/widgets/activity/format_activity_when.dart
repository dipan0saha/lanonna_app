String formatActivityWhen(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return '';
  final local = dt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.isNegative) return _fullDate(local);
  if (diff.inDays < 7) {
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m == 1 ? '1 minute ago' : '$m minutes ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return h == 1 ? '1 hour ago' : '$h hours ago';
    }
    final d = diff.inDays;
    return d == 1 ? '1 day ago' : '$d days ago';
  }
  return _fullDate(local);
}

String _fullDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
