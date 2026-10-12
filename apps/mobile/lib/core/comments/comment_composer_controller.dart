import 'package:flutter/widgets.dart';

import '../input/app_text_input_kind.dart';
import 'comment_thread_port.dart';

/// Owns the detail-screen comment field, its focus, and a single in-flight send.
class CommentComposerController extends ChangeNotifier {
  CommentComposerController({
    required CommentThreadPort port,
    required Future<void> Function() onPosted,
    this.onError,
  })  : _port = port,
        _onPosted = onPosted {
    textController.addListener(_onTextChanged);
  }

  final CommentThreadPort _port;
  final Future<void> Function() _onPosted;
  final void Function(Object error)? onError;

  final textController = TextEditingController();
  final focusNode = FocusNode();

  var sending = false;
  var _disposed = false;

  bool get canSend => !sending && textController.text.trim().isNotEmpty;

  /// Drops focus before a sub-route is pushed and again when it returns,
  /// so route restoration cannot open the keyboard on the comment field.
  void unfocus() {
    focusNode.unfocus();
    final scopeContext = focusNode.context;
    if (scopeContext != null) {
      FocusScope.of(scopeContext).unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> submit() async {
    if (sending || _disposed) return;
    final text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      textController.text,
    );
    if (text.isEmpty) return;
    sending = true;
    _notify();
    try {
      await _port.add(text);
      if (_disposed) return;
      textController.clear();
      await _onPosted();
    } catch (e) {
      if (!_disposed) onError?.call(e);
    } finally {
      sending = false;
      _notify();
    }
  }

  void _onTextChanged() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    textController.removeListener(_onTextChanged);
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
