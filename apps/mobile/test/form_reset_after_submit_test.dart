import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/validation/form_reset_after_submit.dart';

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.formKey,
    required this.controller,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  var _validateOnInteraction = false;

  void enableValidation() => setState(() => _validateOnInteraction = true);

  void disableValidationAndReset() {
    setState(() => _validateOnInteraction = false);
    resetControlledFormAfterSuccessfulSubmit(
      formKey: widget.formKey,
      controller: widget.controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    final autovalidate = _validateOnInteraction
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;
    return Form(
      key: widget.formKey,
      autovalidateMode: autovalidate,
      child: TextFormField(
        controller: widget.controller,
        autovalidateMode: autovalidate,
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }
}

void main() {
  testWidgets('resetControlledFormAfterSuccessfulSubmit clears controlled field',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    final harnessKey = GlobalKey<_HarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _Harness(
            key: harnessKey,
            formKey: formKey,
            controller: controller,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Juniper');
    harnessKey.currentState!.enableValidation();
    await tester.pump();

    harnessKey.currentState!.disableValidationAndReset();
    await tester.pump();
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.text('Required'), findsNothing);
  });
}
