import '../models/activity_model.dart';
import '../models/user_vehicle_model.dart';
import 'database_helper.dart';
import 'localization_service.dart';

class ActivityService {
  final DatabaseHelper _db = DatabaseHelper();

  // Genel aktivite ekleme
  Future<void> logActivity({
    required String userId,
    required ActivityType type,
    required String title,
    required String description,
    double? amount,
  }) async {
    final activity = Activity.create(
      userId: userId,
      type: type,
      title: title,
      description: description,
      amount: amount,
    );
    await _db.addActivity(activity);
  }

  // Araç satın alma
  Future<void> logVehiclePurchase(String userId, UserVehicle vehicle) async {
    await logActivity(
      userId: userId,
      type: ActivityType.purchase,
      title: 'activity.purchaseTitle'.tr(),
      description: 'activity.purchaseDesc'.trParams({
        'brand': vehicle.brand,
        'model': vehicle.model,
      }),
      amount: -vehicle.purchasePrice,
    );
  }

  // Araç satışı
  Future<void> logVehicleSale(String userId, UserVehicle vehicle, double salePrice) async {
    final profit = salePrice - vehicle.purchasePrice;
    await logActivity(
      userId: userId,
      type: ActivityType.sale,
      title: 'activity.saleTitle'.tr(),
      description: 'activity.saleDesc'.trParams({
        'brand': vehicle.brand,
        'model': vehicle.model,
        'profit': profit.toStringAsFixed(0),
      }),
      amount: salePrice,
    );
  }

  // Kira geliri
  Future<void> logRentalIncome(String userId, double amount, int vehicleCount) async {
    await logActivity(
      userId: userId,
      type: ActivityType.rental,
      title: 'activity.rentalTitle'.tr(),
      description: 'activity.rentalDesc'.trParams({
        'count': vehicleCount.toString(),
      }),
      amount: amount,
    );
  }

  // Seviye atlama
  Future<void> logLevelUp(String userId, int newLevel, double rewardAmount) async {
    await logActivity(
      userId: userId,
      type: ActivityType.levelUp,
      title: 'activity.levelUpTitle'.tr(),
      description: 'activity.levelUpDesc'.trParams({
        'level': newLevel.toString(),
      }),
      amount: rewardAmount > 0 ? rewardAmount : null,
    );
  }

  // Taksi kazancı
  Future<void> logTaxiEarnings(String userId, double amount) async {
    await logActivity(
      userId: userId,
      type: ActivityType.taxi,
      title: 'activity.taxiTitle'.tr(),
      description: 'activity.taxiDesc'.tr(),
      amount: amount,
    );
  }

  // Günlük giriş bonusu
  Future<void> logDailyLogin(String userId, double amount) async {
    await logActivity(
      userId: userId,
      type: ActivityType.dailyLogin,
      title: 'activity.dailyLoginTitle'.tr(),
      description: 'activity.dailyLoginDesc'.tr(),
      amount: amount,
    );
  }

  // Kullanıcının aktivitelerini getir
  Future<List<Activity>> getUserActivities(String userId) async {
    return await _db.getUserActivities(userId);
  }

  // Tüm aktiviteleri sil
  Future<void> clearAllActivities(String userId) async {
    await _db.clearUserActivities(userId);
  }
}
