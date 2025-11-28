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
  static const String _keyGameStartTime = 'game_start_time';
  static const String _keyGameDayDuration = 'game_day_duration';
  static const String _keyLastMarketRefresh = 'last_market_refresh';
  static const String _keyTotalPlayedMinutes = 'total_played_minutes';
  static const String _keyLastNotificationReset = 'last_notification_reset';

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

  // Game Time Settings
  static Future<DateTime?> getGameStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyGameStartTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  static Future<void> setGameStartTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGameStartTime, time.millisecondsSinceEpoch);
  }

  static Future<int> getGameDayDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyGameDayDuration) ?? 10; // Default: 10 dakika
  }

  static Future<void> setGameDayDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGameDayDuration, minutes);
  }

  // Market Refresh
  static Future<DateTime?> getLastMarketRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyLastMarketRefresh);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  static Future<void> setLastMarketRefresh(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastMarketRefresh, time.millisecondsSinceEpoch);
  }

  // Total Played Minutes (Aktif oyun süresi)
  static Future<int> getTotalPlayedMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalPlayedMinutes) ?? 0;
  }

  static Future<void> setTotalPlayedMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalPlayedMinutes, minutes);
  }

  // Last Notification Reset (Son bildirim sıfırlama zamanı)
  static Future<DateTime?> getLastNotificationReset() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyLastNotificationReset);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  static Future<void> setLastNotificationReset(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastNotificationReset, time.millisecondsSinceEpoch);
  }

  // Clear all settings
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}

