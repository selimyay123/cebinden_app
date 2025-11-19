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
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo veya uygulama ikonu
            Image.asset(
              'assets/images/app_logo/cebinden_no_bg.png',
              height: 180,
              width: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            // Uygulama adı
            Text(
              'app.name'.tr(),
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'app.subtitle'.tr(),
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            // Yükleniyor göstergesi
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

