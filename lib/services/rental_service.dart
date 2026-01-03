import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import 'activity_service.dart';

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
        // Sadece kirada olan araçlardan gelir elde edilir
        if (vehicle.isRented) {
          double rentalIncome = vehicle.purchasePrice * dailyRentalRate;
          

          
          totalRental += rentalIncome;
        }
      }

      return totalRental;
    } catch (e) {

      return 0.0;
    }
  }

  /// Günlük kiralama işlemini gerçekleştir
  /// Artık bakiyeye eklemez, araç bazında "toplanabilir" olarak işaretler
  Future<double> processDailyRental(String userId) async {
    try {
      // Kullanıcıyı al
      final userJson = await _db.getUserById(userId);
      if (userJson == null) return 0.0;
      
      final user = User.fromJson(userJson);

      // Galeri sahibi değilse kiralama yok
      if (!user.ownsGallery) return 0.0;

      // Kullanıcının aktif araçlarını al
      final vehicles = await _db.getUserActiveVehicles(userId);
      
      double totalNewPending = 0.0;
      
      for (var vehicle in vehicles) {
        // Sadece kirada olan ve henüz toplanmamış geliri olmayan araçlar yeni gelir üretir
        if (vehicle.isRented && !vehicle.canCollectRentalIncome) {
          double rentalIncome = vehicle.purchasePrice * dailyRentalRate;
          
          // Aracı güncelle: Gelir beklemede ve toplanabilir
          final updatedVehicle = vehicle.copyWith(
            pendingRentalIncome: rentalIncome,
            canCollectRentalIncome: true,
          );
          
          await _db.updateUserVehicle(vehicle.id, updatedVehicle.toJson());
          totalNewPending += rentalIncome;
        }
      }

      return totalNewPending;
    } catch (e) {
      return 0.0;
    }
  }

  /// Bekleyen kira gelirini topla
  Future<bool> collectRentalIncome(String userId, String vehicleId) async {
    try {
      final vehicle = await _db.getUserVehicleById(vehicleId);
      if (vehicle == null || !vehicle.canCollectRentalIncome) return false;

      final income = vehicle.pendingRentalIncome;
      if (income <= 0) return false;

      // Kullanıcıyı al
      final userJson = await _db.getUserById(userId);
      if (userJson == null) return false;
      final user = User.fromJson(userJson);

      // Bakiyeyi güncelle
      final newBalance = user.balance + income;
      final newTotalRental = user.totalRentalIncome + income;

      await _db.updateUser(userId, {
        'balance': newBalance,
        'totalRentalIncome': newTotalRental,
        'lastDailyRentalIncome': income,
      });

      // Aracı güncelle: Bekleyen geliri sıfırla ve toplanabilirliği kapat
      final updatedVehicle = vehicle.copyWith(
        pendingRentalIncome: 0.0,
        canCollectRentalIncome: false,
      );
      await _db.updateUserVehicle(vehicleId, updatedVehicle.toJson());

      // Aktivite kaydı
      await ActivityService().logRentalIncome(userId, income, 1);

      return true;
    } catch (e) {
      return false;
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


  /// Aracı kiraya ver
  Future<bool> rentVehicle(String vehicleId) async {
    try {
      final vehicle = await _db.getUserVehicleById(vehicleId);
      if (vehicle == null) return false;

      // Satışta olan araç artık kiralanabilir
      // if (vehicle.isListedForSale) return false;

      // Zaten kiradaysa işlem yapma
      if (vehicle.isRented) return true;

      final updatedVehicle = vehicle.copyWithRent(isRented: true);
      return await _db.updateUserVehicle(vehicleId, updatedVehicle.toJson());
    } catch (e) {
      return false;
    }
  }

  /// Aracı kiradan çek
  Future<bool> stopRentingVehicle(String vehicleId) async {
    try {
      final vehicle = await _db.getUserVehicleById(vehicleId);
      if (vehicle == null) return false;

      // Zaten kirada değilse işlem yapma
      if (!vehicle.isRented) return true;

      final updatedVehicle = vehicle.copyWithRent(isRented: false);
      return await _db.updateUserVehicle(vehicleId, updatedVehicle.toJson());
    } catch (e) {
      return false;
    }
  }

  /// Kiralanabilir araçları getir (Satışta olmayan ve kirada olmayanlar)
  Future<List<UserVehicle>> getRentableVehicles(String userId) async {
    try {
      final vehicles = await _db.getUserActiveVehicles(userId);
      // Satışta olanlar da kiralanabilir, sadece kirada olmayanları getir
      return vehicles.where((v) => !v.isRented).toList();
    } catch (e) {
      return [];
    }
  }

  /// Kiradaki araçları getir
  Future<List<UserVehicle>> getRentedVehicles(String userId) async {
    try {
      final vehicles = await _db.getUserActiveVehicles(userId);
      return vehicles.where((v) => v.isRented).toList();
    } catch (e) {
      return [];
    }
  }
}
