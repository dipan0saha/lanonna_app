import 'package:flutter/widgets.dart';

/// Clears comment composer focus (event detail after edit / refresh).
void unfocusEventCommentComposer(FocusNode commentFocusNode) {
  commentFocusNode.unfocus();
  final scopeContext = commentFocusNode.context;
  if (scopeContext != null) {
    FocusScope.of(scopeContext).unfocus();
  }
  FocusManager.instance.primaryFocus?.unfocus();
}
