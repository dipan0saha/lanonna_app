import 'package:flutter/material.dart';

class RegistryScreen extends StatelessWidget {
  const RegistryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registry')),
      body: const Center(child: Text('Registry — FR-REG')),
    );
  }
}
