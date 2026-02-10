import 'package:flutter/material.dart';

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color? textColor;
  final bool isOutlined;
  final bool isFullWidth;
  final double? width;
  final double height;
  final double borderRadius;
  final List<Color>? gradientColors;

  const ModernButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = Colors.deepPurple,
    this.textColor,
    this.isOutlined = false,
    this.isFullWidth = true,
    this.width,
    this.height = 50,
    this.borderRadius = 12,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? (isOutlined ? color : Colors.white);
    
    // Gradient colors
    final List<Color> effectiveGradient = gradientColors ?? [
      color,
      Color.lerp(color, isOutlined ? Colors.white : Colors.black, 0.1) ?? color,
    ];

    Widget buttonContent = Center(
      child: Text(
        text,
        style: TextStyle(
          color: effectiveTextColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    );

    if (isOutlined) {
      return SizedBox(
        width: isFullWidth ? double.infinity : width,
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            elevation: 0,
          ),
          child: buttonContent,
        ),
      );
    }

    return Container(
      width: isFullWidth ? double.infinity : width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: effectiveGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          // Glow effect
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: buttonContent,
        ),
      ),
    );
  }
}
