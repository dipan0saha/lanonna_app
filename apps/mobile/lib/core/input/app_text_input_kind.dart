import 'package:flutter/services.dart';

import 'person_name_input.dart';
import 'prose_sentence_input.dart';

/// How user-entered text should be capitalized in the UI and on submit.
enum AppTextInputKind {
  /// Email, password, URLs, search — trim only on submit.
  none,

  /// Baby names, profile names — title-case per word.
  personName,

  /// Captions, comments, titles, descriptions — sentence case.
  prose,
}

abstract final class AppTextInputPolicy {
  static TextCapitalization capitalization(AppTextInputKind kind) {
    switch (kind) {
      case AppTextInputKind.none:
        return TextCapitalization.none;
      case AppTextInputKind.personName:
        return personNameTextCapitalization;
      case AppTextInputKind.prose:
        return proseSentenceTextCapitalization;
    }
  }

  static List<TextInputFormatter>? formatters(AppTextInputKind kind) {
    switch (kind) {
      case AppTextInputKind.none:
        return null;
      case AppTextInputKind.personName:
        return personNameInputFormatters;
      case AppTextInputKind.prose:
        return proseSentenceInputFormatters;
    }
  }

  static String normalizeForSubmit(AppTextInputKind kind, String raw) {
    switch (kind) {
      case AppTextInputKind.none:
        return raw.trim();
      case AppTextInputKind.personName:
        return formatPersonName(raw);
      case AppTextInputKind.prose:
        return formatProseSentence(raw);
    }
  }
}
