import 'package:flutter/material.dart';

class CustomSnackBar extends SnackBar {
  CustomSnackBar({
    Key? key,
    required Widget content,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) : super(
          key: key,
          content: content,
          backgroundColor: (backgroundColor ?? Colors.black).withOpacity(0.8),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          duration: duration,
          action: action,
        );
}
