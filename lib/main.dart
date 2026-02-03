import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/resource_download_screen.dart';
import 'services/database_helper.dart';
import 'services/favorite_service.dart';
import 'services/localization_service.dart';
import 'services/asset_service.dart';
import 'services/ad_service.dart';
import 'services/game_time_service.dart';
import 'services/market_refresh_service.dart';
import 'services/offer_service.dart';
import 'utils/route_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i initialize et
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Hive database'i initialize et
  await DatabaseHelper.init();

  // Favorite service'i initialize et
  await FavoriteService.init();

  // Asset service'i initialize et
  await AssetService().init();

  // Localization'ı initialize et
  await LocalizationService().initialize();

  // AdMob'u initialize et (Test Mode)
  await AdService.initialize();

  // Oyun zamanı sistemini başlat
  await GameTimeService().initialize();

  // Pazar yenileme sistemini başlat
  await MarketRefreshService().initialize();

  // Günlük teklif sistemini başlat
  await OfferService().initialize();

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
        return MaterialApp(
          title: 'Cebinden',
          navigatorObservers: [routeObserver],
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
            fontFamily: 'Telegraf',
            appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
          ),
          home: const ResourceDownloadScreen(),
        );
      },
    );
  }
}
