import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Resets a [Form] that contains a controlled [TextFormField] after a successful
/// submit.
///
/// Call after turning deferred autovalidate off (e.g. in [setState]) so clearing
/// the controller does not validate an empty field. Schedules [FormState.reset]
/// on the next frame so each field's `initialValue` matches the cleared
/// controller (#402).
void resetControlledFormAfterSuccessfulSubmit({
  required GlobalKey<FormState> formKey,
  required TextEditingController controller,
}) {
  controller.clear();
  SchedulerBinding.instance.addPostFrameCallback((_) {
    formKey.currentState?.reset();
  });
}
