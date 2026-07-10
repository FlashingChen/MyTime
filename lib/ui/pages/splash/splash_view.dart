import 'package:flutter/material.dart';

/// A simple splash/about page displaying the MyTime logo.
class SplashPage extends StatelessWidget {
  /// Creates a [SplashPage].
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Semantics(
            label: 'MyTime 标志',
            child: const Image(
              image: AssetImage('assets/logo/logo.png'),
              width: 192,
              height: 192,
            ),
          ),
        ),
      ),
    );
  }
}
