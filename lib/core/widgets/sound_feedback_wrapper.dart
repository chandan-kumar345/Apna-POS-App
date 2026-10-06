import 'package:flutter/material.dart';

/// App-wide widget wrapper for sound and feedback management.
/// Designed for zero-overhead, buttery-smooth 60/120 FPS performance without platform channel spam.
class SoundFeedbackWrapper extends StatelessWidget {
  final Widget child;

  const SoundFeedbackWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
