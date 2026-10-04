import 'package:flutter/material.dart';

/// Stable [Semantics.identifier] values for Maestro (`tapOn: id: …`).
class AppSemantics {
  const AppSemantics._();

  static Widget button(
    String identifier,
    Widget child, {
    String? label,
  }) {
    return Semantics(
      identifier: identifier,
      label: label,
      button: true,
      child: child,
    );
  }

  static Widget container(String identifier, Widget child) {
    return Semantics(
      identifier: identifier,
      container: true,
      child: child,
    );
  }

  static Widget textField(String identifier, Widget child) {
    return Semantics(
      identifier: identifier,
      textField: true,
      child: child,
    );
  }
}
