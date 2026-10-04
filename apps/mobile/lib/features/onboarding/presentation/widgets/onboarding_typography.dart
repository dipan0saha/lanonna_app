import 'package:flutter/material.dart';

import '../../../../core/theme/la_nonna_theme.dart';

class OnboardingFieldLabel extends StatelessWidget {
  const OnboardingFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.fieldLabelStyle);
  }
}

class OnboardingHeadline extends StatelessWidget {
  const OnboardingHeadline(
    this.text, {
    super.key,
    this.textAlign,
  });

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}

class OnboardingSupportText extends StatelessWidget {
  const OnboardingSupportText(
    this.text, {
    super.key,
    this.textAlign,
  });

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
