// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import '../widgets/modern_alert_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with LocalizationMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleRegisterProcess() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    // 1. Validasyonlar
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Lütfen tüm alanları doldurunuz.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Geçersiz e-posta adresi.');
      return;
    }

    if (password != passwordConfirm) {
      _showError('Şifreler eşleşmiyor.');
      return;
    }

    if (username.length < 3) {
      _showError('Kullanıcı adı en az 3 karakter olmalı.');
      return;
    }

    // 2. Kayıt İşlemi
    try {
      final success = await _authService.registerUser(
        username: username,
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (success) {
        // 3. E-posta Doğrulama Gönder
        try {
          await _authService.sendEmailVerification();
          if (!mounted) return;

          setState(() => _isLoading = false);

          // Doğrulama Dialogunu Göster
          _showVerificationDialog(email);
        } catch (e) {
          _showError('Doğrulama e-postası gönderilemedi: $e');
        }
      } else {
        // Kayıt başarısız (Email kullanımda olabilir)
        // Giriş yapmayı dene (Kullanıcı zaten varsa)
        _attemptLoginFallback(email, password);
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    }
  }

  Future<void> _attemptLoginFallback(String email, String password) async {
    try {
      final existingUser = await _authService.login(
        username: email,
        password: password,
      );

      if (existingUser != null) {
        _navigateToHome();
      } else {
        _showError(
          'Bu e-posta kullanımda. Giriş yapmayı denedik ancak başarısız oldu. Lütfen giriş yap ekranını kullanın.',
        );
      }
    } catch (e) {
      _showError('Kayıt işlemi başarısız oldu.');
    }
  }

  void _showVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModernAlertDialog(
        title: 'E-posta Doğrulama',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$email adresine bir doğrulama bağlantısı gönderdik.\n\nLütfen e-postanızı kontrol edin, bağlantıya tıklayın ve ardından aşağıdaki butona basın.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        buttonText: 'Doğruladım, Devam Et',
        onPressed: () async {
          // Doğrulama kontrolü
          Navigator.pop(context); // Dialogu kapat (loading göstereceğiz)
          _checkVerificationStatus();
        },
        secondaryButtonText: 'Tekrar Gönder',
        onSecondaryPressed: () async {
          Navigator.pop(context);
          await _authService.sendEmailVerification();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bağlantı tekrar gönderildi.')),
            );
            // Recursive call'den önce dialogu kapatıp yeni dialog açma mantığı yerine
            // Mevcut dialogda kalmak daha mantıklı olabilir ama burada tekrar dialog çağrısı var.
            // Bu uyarı recursion yaratabilir, dikkatli olunmalı.
            // Kullanıcı zaten dialogda, tekrar gönder'e bastı.
            // En iyisi bir bilgi verip dialogu kapatmamak veya yenisini açmak.
            // _showVerificationDialog(email); // Recursive call'u kaldırıyorum, kullanıcı tekrar basabilir.
          }
        },
      ),
    );
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isLoading = true);

    try {
      await _authService.reloadUser();
      final isVerified = _authService.isEmailVerified;

      if (!mounted) return;

      if (isVerified) {
        // Başarılı!
        _navigateToHome();
      } else {
        setState(() => _isLoading = false);
        // Hata ve tekrar dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('E-posta henüz doğrulanmamış.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: () => _showVerificationDialog(_emailController.text),
            ),
          ),
        );
        // Dialogu tekrar göster ki kullanıcı sıkışmasın
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isLoading) {
            _showVerificationDialog(_emailController.text);
          }
        });
      }
    } catch (e) {
      _showError('Doğrulama kontrolü sırasında hata oluştu.');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  void _navigateToHome() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/app_logo/cebinden_no_bg.png',
                  height: 180,
                  width: 180,
                  fit: BoxFit.contain,
                ),
                Text(
                  'app.name'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'app.subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 25),
                Text(
                  'auth.register'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'auth.createAccountTitle'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _usernameController,
                  enabled: !_isLoading,
                  maxLength: 30,
                  decoration: InputDecoration(
                    labelText: 'auth.username'.tr(),
                    hintText: 'auth.enterUsername'.tr(),
                    prefixIcon: const Icon(Icons.person),
                    counterText: "",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-posta',
                    hintText: 'E-posta adresinizi giriniz',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'auth.password'.tr(),
                    hintText: 'auth.enterPassword'.tr(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordConfirmController,
                  enabled: !_isLoading,
                  obscureText: _obscurePasswordConfirm,
                  decoration: InputDecoration(
                    labelText: 'auth.confirmPassword'.tr(),
                    hintText: 'auth.enterPasswordAgain'.tr(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasswordConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePasswordConfirm = !_obscurePasswordConfirm;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleRegisterProcess(),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegisterProcess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'auth.register'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'auth.alreadyHaveAccount'.tr(),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'auth.login'.tr(),
                        style: const TextStyle(
                          color: Colors.deepPurple,
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
