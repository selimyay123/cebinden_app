import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'services/database_helper.dart';
import 'services/localization_service.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hive database'i initialize et
  await DatabaseHelper.init();
  
  // Localization'ı initialize et
  await LocalizationService().initialize();
  
  // AdMob'u initialize et (Test Mode)
  await AdService.initialize();
  
  runApp(const CebindenApp());
}

class CebindenApp extends StatelessWidget {
  const CebindenApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService();
    
    // ValueListenableBuilder ile dil değişikliklerini dinle
    return ValueListenableBuilder<String>(
      valueListenable: localizationService.languageNotifier,
      builder: (context, currentLanguage, child) {
        print('🌍 App rebuilding with language: $currentLanguage');
        
        return MaterialApp(
          title: 'Cebinden',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocalizationService.supportedLocales,
          locale: localizationService.currentLocale, // Dinamik locale
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: GoogleFonts.poppins().fontFamily,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
