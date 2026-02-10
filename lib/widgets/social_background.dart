import 'package:flutter/material.dart';

class SocialBackground extends StatelessWidget {
  final Widget child;

  const SocialBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Fallback color
        image: DecorationImage(
          image: const AssetImage('assets/images/social_bg_abstract.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(
              alpha: 0.2,
            ), // Slight darkening for text readability
            BlendMode.darken,
          ),
        ),
      ),
      child: child,
    );
  }
}
