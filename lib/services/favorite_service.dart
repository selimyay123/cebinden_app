import 'package:hive_flutter/hive_flutter.dart';
import '../models/vehicle_model.dart';
import 'market_refresh_service.dart';

/// Favori ilanları yöneten servis
class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  // Box ismi
  static const String favoritesBox = 'favorites';

  // Initialize - Hive box'ını aç
  static Future<void> init() async {
    await Hive.openBox<Map>(favoritesBox);
  }

  // Favorites box'ını al
  Box<Map> get _favoritesBox => Hive.box<Map>(favoritesBox);

  /// Favorilere ilan ekle
  /// Key format: "{userId}_{vehicleId}"
  Future<bool> addFavorite(String userId, Vehicle vehicle) async {
    try {
      final key = '${userId}_${vehicle.id}';
      final vehicleMap = vehicle.toJson();
      await _favoritesBox.put(key, vehicleMap);
      await _favoritesBox.flush();
      return true;
    } catch (e) {

      return false;
    }
  }

  /// Favorilerden ilan kaldır
  Future<bool> removeFavorite(String userId, String vehicleId) async {
    try {
      final key = '${userId}_$vehicleId';
      await _favoritesBox.delete(key);
      await _favoritesBox.flush();
      return true;
    } catch (e) {

      return false;
    }
  }

  /// İlan favorilerde mi kontrol et
  bool isFavorite(String userId, String vehicleId) {
    try {
      final key = '${userId}_$vehicleId';
      return _favoritesBox.containsKey(key);
    } catch (e) {

      return false;
    }
  }

  /// Kullanıcının tüm favori ilanlarını getir
  Future<List<Vehicle>> getUserFavorites(String userId) async {
    try {
      final List<Vehicle> favorites = [];
      
      // Kullanıcıya ait tüm favorileri bul
      for (var entry in _favoritesBox.toMap().entries) {
        final String key = entry.key.toString();
        if (key.startsWith('${userId}_')) {
          try {
            final vehicleMap = Map<String, dynamic>.from(entry.value);
            final storedVehicle = Vehicle.fromJson(vehicleMap);
            
            // Market servisinden güncel veriyi kontrol et
            // Eğer araç hala markette ise, güncel halini (ekspertiz yapılmış vs.) al
            final marketVehicle = MarketRefreshService().getVehicleById(storedVehicle.id);
            
            if (marketVehicle != null) {
              favorites.add(marketVehicle);
            } else {
              // Araç markette yoksa (satılmış veya süresi dolmuş), favorilerden de temizle
              await _favoritesBox.delete(key);
            }
          } catch (e) {

          }
        }
      }
      
      // Tarihe göre sırala (en yeniler önce)
      favorites.sort((a, b) => b.listedAt.compareTo(a.listedAt));
      
      return favorites;
    } catch (e) {

      return [];
    }
  }

  /// Kullanıcının favori sayısını getir
  int getFavoriteCount(String userId) {
    try {
      int count = 0;
      for (var key in _favoritesBox.keys) {
        if (key.toString().startsWith('${userId}_')) {
          count++;
        }
      }
      return count;
    } catch (e) {

      return 0;
    }
  }

  /// Belirli bir ilanı tüm kullanıcıların favorilerinden kaldır
  /// (İlan satıldığında çağrılır)
  Future<void> removeVehicleFromAllFavorites(String vehicleId) async {
    try {
      final List<String> keysToRemove = [];
      
      // İlana ait tüm favori kayıtlarını bul
      for (var key in _favoritesBox.keys) {
        if (key.toString().endsWith('_$vehicleId')) {
          keysToRemove.add(key.toString());
        }
      }
      
      // Toplu silme
      for (var key in keysToRemove) {
        await _favoritesBox.delete(key);
      }
      
      await _favoritesBox.flush();

    } catch (e) {

    }
  }

  /// Kullanıcının tüm favorilerini temizle
  Future<void> clearUserFavorites(String userId) async {
    try {
      final List<String> keysToRemove = [];
      
      for (var key in _favoritesBox.keys) {
        if (key.toString().startsWith('${userId}_')) {
          keysToRemove.add(key.toString());
        }
      }
      
      for (var key in keysToRemove) {
        await _favoritesBox.delete(key);
      }
      
      await _favoritesBox.flush();
    } catch (e) {

    }
  }
}

