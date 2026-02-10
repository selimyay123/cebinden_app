// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/localization_service.dart';
import '../services/database_helper.dart';
import '../services/cloud_service.dart';
import '../models/user_model.dart';
import 'main_screen.dart';
import 'register_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with LocalizationMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController();

    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Şifre Sıfırlama'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'E-posta adresinizi girin, size şifre sıfırlama bağlantısı gönderelim.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;

                // Dialog'u kapat
                Navigator.of(dialogContext).pop();

                // Loading göster
                setState(() => _isLoading = true);

                final success = await FirebaseAuthService()
                    .sendPasswordResetEmail(email);

                setState(() => _isLoading = false);

                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sıfırlama bağlantısı e-posta adresinize gönderildi.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'E-posta gönderilemedi. Lütfen adresi kontrol edin.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'auth.usernameRequired'.tr();
        _isLoading = false;
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'auth.passwordRequired'.tr();
        _isLoading = false;
      });
      return;
    }

    // Giriş mantığı:
    // 1. Önce E-posta ile giriş yapmayı dene (Firebase Auth)
    // 2. Başarısız olursa, eski yöntemle (Kullanıcı Adı) dene (Legacy support)

    User? user;

    // E-posta formatındaysa direkt Firebase deniyoruz
    final isEmail = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(username);

    if (isEmail) {
      try {
        final firebaseUser = await FirebaseAuthService()
            .signInWithEmailAndPassword(username, password);
        if (firebaseUser != null) {
          // Firebase girişi başarılı, şimdi veritabanından kullanıcı verisini çekelim
          // ID change: Firebase UID is used as User ID in our DB

          // Önce local DB'ye bak
          final localUserMap = await DatabaseHelper().getUserById(
            firebaseUser.uid,
          );
          if (localUserMap != null) {
            user = User.fromJson(localUserMap);
          } else {
            // Localde yoksa Cloud'dan çek (Yeni cihaz senaryosu)
            final cloudUser = await CloudService().getUserById(
              firebaseUser.uid,
            );
            if (cloudUser != null) {
              user = cloudUser;
              // Local'e kaydet
              await DatabaseHelper().insertUser(user.toJson());

              // Araçları çek ve kaydet
              final vehicles = await CloudService().getUserVehicles(user.id);
              for (var vehicle in vehicles) {
                await DatabaseHelper().addUserVehicle(vehicle);
              }
            }
          }
        }
      } catch (e) {
        // E-posta girişi başarısız, belki kullanıcı adı olarak girilmiştir veya hata vardır.
        // Devam et...
      }
    }

    // Eğer E-posta ile giriş yapılamadıysa veya format e-posta değilse, eski usul dene
    user ??= await _authService.login(username: username, password: password);

    if (!mounted) return;

    if (user != null) {
      // Başarılı giriş - Tüm route geçmişini temizle
      await DatabaseHelper().setCurrentUser(
        user.id,
      ); // 🟢 FIX: Aktif kullanıcıyı kaydet!

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false, // Tüm önceki ekranları temizle
      );
    } else {
      setState(() {
        _errorMessage = 'auth.invalidCredentials'.tr();
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.loginWithGoogle();

      if (!mounted) return;

      if (user != null) {
        // Başarılı Google girişi

        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = 'login.googleLoginFailed'.tr();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'login.googleLoginError'.tr();
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.loginWithApple();

      if (!mounted) return;

      if (user != null) {
        // Başarılı Apple girişi

        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = 'purchase.appleLoginFailed'.tr();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'purchase.appleLoginError'.tr();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/app_logo/cebinden_no_bg.png',
                    height: 180,
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                  // const SizedBox(height: 10),

                  // Başlık
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
                  const SizedBox(height: 20),

                  // Alt başlık
                  Text(
                    'auth.login'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Kullanıcı adı
                  TextField(
                    controller: _usernameController,
                    enabled: !_isLoading,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: 'auth.emailOrUsername'.tr(),
                      hintText: 'auth.enterEmailAddress'.tr(),
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.deepPurple,
                          width: 2,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Şifre
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
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.deepPurple,
                          width: 2,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 8),

                  // Şifremi Unuttum
                  Center(
                    child: TextButton(
                      onPressed: () {
                        _showForgotPasswordDialog(context);
                      },
                      child: Text(
                        'auth.forgotPasswordQuestion'.tr(),
                        style: TextStyle(
                          color: Colors.deepPurple[400],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Hata mesajı
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
                  const SizedBox(height: 24),

                  // Giriş yap butonu
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
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
                              'auth.login'.tr(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ayraç - "veya"
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[400])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'login.or'.tr(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[400])),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Google ile giriş butonu
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loginWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      icon: const FaIcon(
                        FontAwesomeIcons.google,
                        color: Color(0xFFDB4437), // Google Red
                        size: 24,
                      ),
                      label: Text(
                        'login.googleSignIn'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                  // Apple ile giriş butonu (Sadece iOS)
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _loginWithApple,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        icon: const FaIcon(
                          FontAwesomeIcons.apple,
                          color: Colors.white,
                          size: 24,
                        ),
                        label: Text(
                          'purchase.appleSignIn'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Kayıt ol linki
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${'auth.noAccount'.tr()} ',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegisterScreen(),
                                  ),
                                );
                              },
                        child: Text(
                          'auth.register'.tr(),
                          style: const TextStyle(
                            fontSize: 14,
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
      ),
    );
  }
}
