import 'package:flutter/material.dart';

class CustomSnackBar extends SnackBar {
  CustomSnackBar({
    super.key,
    required super.content,
    Color? backgroundColor,
    super.duration = const Duration(milliseconds: 1500),
    super.action,
  }) : super(
         backgroundColor: (backgroundColor ?? Colors.black).withValues(alpha: 0.8),
         elevation: 8,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
         behavior: SnackBarBehavior.floating,
       );
}
