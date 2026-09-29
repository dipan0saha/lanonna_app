import 'package:flutter/material.dart';

class FunScreen extends StatelessWidget {
  const FunScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('gamification_screen'),
      appBar: AppBar(title: const Text('Fun')),
      body: const Center(child: Text('Predictions & name ideas — FR-GAM')),
    );
  }
}
