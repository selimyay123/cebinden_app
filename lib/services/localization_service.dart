import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dil yönetimi servisi
class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  static const String _languageKey = 'app_language';
  static const String _defaultLanguage = 'en'; // Evrensel fallback dili

  Map<String, dynamic> _localizedStrings = {};
  String _currentLanguage = _defaultLanguage;

  // ValueNotifier ile reactive dil değişimi
  final ValueNotifier<String> languageNotifier = ValueNotifier<String>(
    _defaultLanguage,
  );

  /// Mevcut dil
  String get currentLanguage => _currentLanguage;

  /// Mevcut locale
  Locale get currentLocale => Locale(_currentLanguage);

  /// Desteklenen diller
  static const List<String> supportedLanguages = ['tr', 'en', 'es'];

  /// Desteklenen locale'ler
  static const List<Locale> supportedLocales = [
    Locale('tr', 'TR'),
    Locale('en', 'US'),
    Locale('es', 'ES'),
  ];

  /// Cihazın sistem dilini al
  String _getDeviceLanguage() {
    try {
      // Platform dispatcher'dan sistem dilini al
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final languageCode = systemLocale.languageCode.toLowerCase();

      // Eğer cihaz dili Türkçe ise Türkçe yap
      if (languageCode == 'tr') {
        return 'tr';
      }

      // Diğer tüm durumlarda (İngilizce veya başka diller) varsayılan olarak İngilizce yap
      return 'en';
    } catch (e) {
      return 'en'; // Hata durumunda İngilizce
    }
  }

  /// Initialize - Kaydedilmiş dili yükle veya sistem dilini kullan
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Daha önce kayıtlı dil var mı kontrol et
      final savedLanguage = prefs.getString(_languageKey);

      if (savedLanguage != null) {
        // Kullanıcı daha önce bir dil seçmiş, onu kullan
        _currentLanguage = savedLanguage;
      } else {
        // İlk kez açılıyor, sistem dilini kullan
        _currentLanguage = _getDeviceLanguage();

        // Seçilen sistem dilini kaydet
        await prefs.setString(_languageKey, _currentLanguage);
      }

      languageNotifier.value = _currentLanguage; // Notifier'ı güncelle
      await _loadLanguageFile(_currentLanguage);
    } catch (e) {
      _currentLanguage = 'en'; // Hata durumunda İngilizce
      languageNotifier.value = 'en';
      await _loadLanguageFile('en');
    }
  }

  /// Dil dosyasını yükle
  Future<void> _loadLanguageFile(String languageCode) async {
    try {
      String jsonString = await rootBundle.loadString(
        'assets/translations/$languageCode.json',
      );
      _localizedStrings = json.decode(jsonString);
    } catch (e) {
      _localizedStrings = {};
    }
  }

  /// Dili değiştir
  Future<bool> changeLanguage(String languageCode) async {
    if (!supportedLanguages.contains(languageCode)) {
      return false;
    }

    try {
      await _loadLanguageFile(languageCode);
      _currentLanguage = languageCode;
      languageNotifier.value =
          languageCode; // Notifier'ı güncelle - UI otomatik yenilenecek!

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Çeviri al - Noktalı path ile (örn: "auth.login")
  String translate(String key, {String? defaultValue}) {
    try {
      List<String> keys = key.split('.');
      dynamic value = _localizedStrings;

      for (String k in keys) {
        if (value is Map<String, dynamic> && value.containsKey(k)) {
          value = value[k];
        } else {
          // Key bulunamazsa varsa default value, yoksa key'in kendisini döndür
          return defaultValue ?? key;
        }
      }

      return value.toString();
    } catch (e) {
      return defaultValue ?? key;
    }
  }

  /// Parametreli çeviri (örn: "Hello {name}" → "Hello John")
  String translateWithParams(
    String key,
    Map<String, String> params, {
    String? defaultValue,
  }) {
    String text = translate(key, defaultValue: defaultValue);

    params.forEach((key, value) {
      text = text.replaceAll('{$key}', value);
    });

    return text;
  }

  /// Liste çevirisi al (örn: "models.descriptions.Renauva.Slim")
  List<String> translateList(String key) {
    try {
      List<String> keys = key.split('.');
      dynamic value = _localizedStrings;

      for (String k in keys) {
        if (value is Map<String, dynamic> && value.containsKey(k)) {
          value = value[k];
        } else {
          return [];
        }
      }

      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

/// Extension - Kolay kullanım için
extension LocalizationExtension on String {
  /// String'i çevir (örn: "auth.login".tr())
  String tr({String? defaultValue}) {
    return LocalizationService().translate(this, defaultValue: defaultValue);
  }

  /// Parametreli çeviri (örn: "hello.message".trParams({'name': 'John'}))
  String trParams(Map<String, String> params) {
    return LocalizationService().translateWithParams(this, params);
  }

  /// Liste çevirisi (örn: "models.descriptions.Renauva.Slim".trList())
  List<String> trList() {
    return LocalizationService().translateList(this);
  }
}

/// Widget mixin - State'lerde kullanmak için
mixin LocalizationMixin<T extends StatefulWidget> on State<T> {
  String tr(String key) => LocalizationService().translate(key);

  String trParams(String key, Map<String, String> params) {
    return LocalizationService().translateWithParams(key, params);
  }

  /// Dil değiştiğinde rebuild tetikle
  void refreshLanguage() {
    if (mounted) {
      setState(() {});
    }
  }
}
