String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Email is required';
  final pattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  if (!pattern.hasMatch(email)) return 'Enter a valid email';
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.length < 6) return 'Password must be at least 6 characters';
  if (!RegExp(r'[\d\W]').hasMatch(password)) {
    return 'Include a number or symbol';
  }
  return null;
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Display name is required';
  if (name.length > 100) return 'Display name is too long';
  return null;
}
