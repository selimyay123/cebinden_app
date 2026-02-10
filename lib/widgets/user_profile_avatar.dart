import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class UserProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? username;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  const UserProfileAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.username,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return _buildAvatar(context);
  }

  Widget _buildAvatar(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.deepPurple.shade100;
    final txtColor = textColor ?? Colors.deepPurple.shade700;
    final fSize = fontSize ?? (radius);

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // Lottie Animation
      if (imageUrl!.endsWith('.json')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          child: ClipOval(
            child: Lottie.asset(
              imageUrl!,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallback(bgColor, txtColor, fSize);
              },
            ),
          ),
        );
      }

      // Asset Image
      if (imageUrl!.startsWith('assets/')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage: AssetImage(imageUrl!),
          onBackgroundImageError: (_, __) {},
        );
      }

      // Network Image
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }

    return _buildFallback(bgColor, txtColor, fSize);
  }

  Widget _buildFallback(Color bgColor, Color txtColor, double fSize) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        (username != null && username!.isNotEmpty)
            ? username![0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: fSize,
          fontWeight: FontWeight.bold,
          color: txtColor,
        ),
      ),
    );
  }
}
