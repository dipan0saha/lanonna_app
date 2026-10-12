import 'package:flutter/widgets.dart';

/// Drops focus from [node] and the surrounding scope so the keyboard closes.
///
/// Shared by the comment composer and the photo caption field. Removing a
/// focused field without this leaves the keyboard up.
void dismissTextInputFocus(FocusNode? node) {
  node?.unfocus();
  final scopeContext = node?.context;
  if (scopeContext != null) {
    FocusScope.of(scopeContext).unfocus();
  }
  FocusManager.instance.primaryFocus?.unfocus();
}
