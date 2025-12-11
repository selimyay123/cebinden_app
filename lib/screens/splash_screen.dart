import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Kullanıcı kontrolü için kısa bir bekleme (splash ekranı gösterimi için)
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      // Aktif kullanıcı var mı kontrol et
      
      final userExists = await _authService.checkUserExists();
      
      if (userExists) {
        final currentUser = await _authService.getCurrentUser();
        
        
      } else {
        
        
      }

      if (!mounted) return;

      if (userExists) {
        // Aktif kullanıcı varsa ana sayfaya yönlendir (tüm geçmişi temizle)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false, // Tüm önceki route'ları temizle
        );
      } else {
        // Aktif kullanıcı yoksa giriş ekranına yönlendir
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // Tüm önceki route'ları temizle
        );
      }
    } catch (e) {
      
      
      // Hata durumunda güvenli olarak login'e yönlendir
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Intro resmi ile uyumlu olması için siyah yapıldı, gerekirse değiştirilebilir
      body: Stack(
        children: [
          Image.asset(
              'assets/images/splash_screen.jpeg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 50.0),
              child: SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

