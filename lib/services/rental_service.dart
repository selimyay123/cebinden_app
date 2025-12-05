import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

/// Galeri sahipleri için araç kiralama hizmeti
class RentalService {
  static final RentalService _instance = RentalService._internal();
  factory RentalService() => _instance;
  RentalService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();

  /// Günlük kiralama oranı (araç değerinin yüzdesi)
  static const double dailyRentalRate = 0.008; // %0.8

  /// Kullanıcının günlük kiralama gelirini hesapla
  Future<double> calculateDailyRentalIncome(String userId) async {
    try {
      // Kullanıcının aktif (satılmamış) araçlarını al
      final vehicles = await _db.getUserActiveVehicles(userId);
      
      if (vehicles.isEmpty) {
        return 0.0;
      }

      // Her araç için kiralama geliri hesapla
      double totalRental = 0.0;
      for (var vehicle in vehicles) {
        final rentalIncome = vehicle.purchasePrice * dailyRentalRate;
        totalRental += rentalIncome;
      }

      return totalRental;
    } catch (e) {

      return 0.0;
    }
  }

  /// Günlük kiralama işlemini gerçekleştir
  /// Returns: Kazanılan kiralama geliri (bildirim için)
  Future<double> processDailyRental(String userId) async {
    try {
      // Kullanıcıyı al
      final userJson = await _db.getUserById(userId);
      if (userJson == null) return 0.0;
      
      final user = User.fromJson(userJson);

      // Galeri sahibi değilse kiralama yok
      if (!user.ownsGallery) return 0.0;

      // Kiralama gelirini hesapla
      final rentalIncome = await calculateDailyRentalIncome(userId);
      
      if (rentalIncome <= 0) return 0.0;

      // Kullanıcının bakiyesini ve istatistiklerini güncelle
      final newBalance = user.balance + rentalIncome;
      final newTotalRental = user.totalRentalIncome + rentalIncome;

      await _db.updateUser(userId, {
        'balance': newBalance,
        'totalRentalIncome': newTotalRental,
        'lastDailyRentalIncome': rentalIncome,
      });

      return rentalIncome;
    } catch (e) {

      return 0.0;
    }
  }

  /// Kiralama istatistiklerini al
  Future<Map<String, dynamic>> getRentalStats(String userId) async {
    try {
      final userJson = await _db.getUserById(userId);
      if (userJson == null) {
        return {
          'vehicleCount': 0,
          'lastDailyIncome': 0.0,
          'totalIncome': 0.0,
          'projectedDaily': 0.0,
        };
      }
      
      final user = User.fromJson(userJson);
      if (!user.ownsGallery) {
        return {
          'vehicleCount': 0,
          'lastDailyIncome': 0.0,
          'totalIncome': 0.0,
          'projectedDaily': 0.0,
        };
      }

      final vehicles = await _db.getUserActiveVehicles(userId);
      final projectedDaily = await calculateDailyRentalIncome(userId);

      return {
        'vehicleCount': vehicles.length,
        'lastDailyIncome': user.lastDailyRentalIncome,
        'totalIncome': user.totalRentalIncome,
        'projectedDaily': projectedDaily,
      };
    } catch (e) {

      return {
        'vehicleCount': 0,
        'lastDailyIncome': 0.0,
        'totalIncome': 0.0,
        'projectedDaily': 0.0,
      };
    }
  }
}
