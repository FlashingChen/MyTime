import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A simple splash/about page displaying the MyTime logo.
class SplashPage extends StatelessWidget {
  /// Creates a [SplashPage].
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetName = isDark
        ? 'assets/logo/logo_dark.svg'
        : 'assets/logo/logo.svg';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1a1a2e)
          : const Color(0xFFF8F9FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Semantics(
            label: 'MyTime 标志',
            child: SvgPicture.asset(assetName, width: 192, height: 192),
          ),
        ),
      ),
    );
  }
}
