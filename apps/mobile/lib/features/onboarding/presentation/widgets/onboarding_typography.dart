import 'package:flutter/material.dart';

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
