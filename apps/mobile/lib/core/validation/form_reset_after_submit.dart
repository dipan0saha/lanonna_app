import 'package:flutter/widgets.dart';

/// Empties a [Form] whose fields use [TextEditingController]s after a
/// successful submit, without leaving a stale "required" error (#397, #402).
///
/// A controlled `TextFormField` uses `controller.text` *at its last build* as
/// its `initialValue`, and [FormState.reset] restores that value. Once the
/// form has rebuilt while the user's text was in the controller (for example
/// when submit turns on deferred validation, or any rebuild during the
/// request), `reset()` alone puts the submitted text back. So this resets
/// first, which drops error text and interaction state, then clears each
/// controller, which is what actually empties the field. It runs
/// synchronously and does not depend on the caller rebuilding first.
///
/// Turn deferred autovalidate off in the same `setState` as this call, so
/// the cleared field is not validated until the next submit.
void resetControlledFormAfterSuccessfulSubmit({
  required GlobalKey<FormState> formKey,
  required Iterable<TextEditingController> controllers,
}) {
  formKey.currentState?.reset();
  for (final controller in controllers) {
    controller.clear();
  }
}
