import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class ReauthenticationDialog extends StatefulWidget {
  final User user;

  const ReauthenticationDialog({super.key, required this.user});

  @override
  State<ReauthenticationDialog> createState() => _ReauthenticationDialogState();
}

class _ReauthenticationDialogState extends State<ReauthenticationDialog>
    with LocalizationMixin {
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleReauth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    bool success = false;

    try {
      if (widget.user.authProvider == 'google') {
        success = await _authService.reauthenticateWithGoogle();
      } else if (widget.user.authProvider == 'apple') {
        success = await _authService.reauthenticateWithApple();
      } else {
        // Email/Password
        final password = _passwordController.text;
        if (password.isEmpty) {
          setState(() {
            _error = 'auth.passwordRequired'.tr();
            _isLoading = false;
          });
          return;
        }
        success = await _authService.reauthenticateWithPassword(password);
      }

      if (success) {
        if (!mounted) return;
        Navigator.of(context).pop(true); // Başarılı
      } else {
        setState(() {
          _error = 'auth.invalidCredentials'.tr();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'settings.reauthRequired'.tr(),
      ), // "Güvenlik gereği tekrar giriş yapmalısınız"
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),

            if (widget.user.authProvider == 'google')
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleReauth,
                icon: const Icon(Icons.g_mobiledata), // FontAwesome yoksa
                label: const Text('Google ile Doğrula'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              )
            else if (widget.user.authProvider == 'apple')
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleReauth,
                icon: const Icon(Icons.apple),
                label: const Text('Apple ile Doğrula'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              )
            else
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'auth.password'.tr(),
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        if (widget.user.authProvider != 'google' &&
            widget.user.authProvider != 'apple')
          ElevatedButton(
            onPressed: _isLoading ? null : _handleReauth,
            child: Text('common.confirm'.tr()),
          ),
      ],
    );
  }
}
