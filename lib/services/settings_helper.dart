import 'package:shared_preferences/shared_preferences.dart';

class SettingsHelper {
  static SettingsHelper? _instance;
  static SharedPreferences? _prefs;

  // Singleton pattern
  SettingsHelper._();

  static Future<SettingsHelper> getInstance() async {
    if (_instance == null) {
      _instance = SettingsHelper._();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // Settings Keys
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyNotificationNewListings = 'notification_new_listings';
  static const String _keyNotificationPriceDrops = 'notification_price_drops';
  static const String _keyNotificationOffers = 'notification_offers';
  static const String _keyNotificationSystem = 'notification_system';

  // Dark Mode
  Future<bool> getDarkMode() async {
    return _prefs?.getBool(_keyDarkMode) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs?.setBool(_keyDarkMode, value);
  }

  // Notification Settings
  Future<bool> getNotificationNewListings() async {
    return _prefs?.getBool(_keyNotificationNewListings) ?? true;
  }

  Future<void> setNotificationNewListings(bool value) async {
    await _prefs?.setBool(_keyNotificationNewListings, value);
  }

  Future<bool> getNotificationPriceDrops() async {
    return _prefs?.getBool(_keyNotificationPriceDrops) ?? true;
  }

  Future<void> setNotificationPriceDrops(bool value) async {
    await _prefs?.setBool(_keyNotificationPriceDrops, value);
  }

  Future<bool> getNotificationOffers() async {
    return _prefs?.getBool(_keyNotificationOffers) ?? true;
  }

  Future<void> setNotificationOffers(bool value) async {
    await _prefs?.setBool(_keyNotificationOffers, value);
  }

  Future<bool> getNotificationSystem() async {
    return _prefs?.getBool(_keyNotificationSystem) ?? true;
  }

  Future<void> setNotificationSystem(bool value) async {
    await _prefs?.setBool(_keyNotificationSystem, value);
  }

  // Clear all settings
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}

