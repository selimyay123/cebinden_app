import 'package:flutter/material.dart';

class ModernAlertDialog extends StatefulWidget {
  final String title;
  final Widget content;
  final String? buttonText;
  final VoidCallback? onPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final IconData? icon;
  final Color? iconColor;
  final List<Widget>? customActions;
  final bool isDestructive;

  const ModernAlertDialog({
    super.key,
    required this.title,
    required this.content,
    this.buttonText,
    this.onPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.icon,
    this.iconColor,
    this.customActions,
    this.isDestructive = false,
  });

  @override
  State<ModernAlertDialog> createState() => _ModernAlertDialogState();
}

class _ModernAlertDialogState extends State<ModernAlertDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.deepPurple, // Mor arka plan
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade400,
                Colors.deepPurple.shade800,
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 48,
                      color: widget.iconColor ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                DefaultTextStyle(
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                  child: widget.content,
                ),
                const SizedBox(height: 32),
                if (widget.customActions != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: widget.customActions!,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.secondaryButtonText != null) ...[
                        TextButton(
                          onPressed: widget.onSecondaryPressed ?? () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                          ),
                          child: Text(
                            widget.secondaryButtonText!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (widget.buttonText != null)
                          ElevatedButton(
                            onPressed: widget.onPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.isDestructive ? Colors.red : Colors.white,
                              foregroundColor: widget.isDestructive ? Colors.white : Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 5,
                            ),
                          child: Text(
                            widget.buttonText!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
