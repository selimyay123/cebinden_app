// ignore_for_file: constant_identifier_names

import '../models/staff_model.dart';
import '../models/activity_model.dart';
import 'dart:async';
import 'database_helper.dart';
import 'localization_service.dart';
// import '../services/game_time_service.dart';
import 'activity_service.dart';
import 'market_refresh_service.dart';

import 'package:flutter/widgets.dart'; // For WidgetsBindingObserver

class StaffService with WidgetsBindingObserver {
  static final StaffService _instance = StaffService._internal();
  factory StaffService() => _instance;
  StaffService._internal();

  static const int CONTRACT_DURATION_DAYS = 3; // 3 Günlük Sözleşme

  // Geçici olarak bellek içi liste (İleride DB'ye taşınacak)
  List<Staff> _myStaff = [];

  // Simülasyonun aktif olup olmadığını takip eder
  List<Staff> get myStaff => _myStaff;

  Future<void> init() async {
    final userMap = await DatabaseHelper().getCurrentUser();
    if (userMap != null) {
      _myStaff = await DatabaseHelper().getAllStaff(userMap['id']);
    } else {
      _myStaff = [];
    }

    // Lifecycle observer ekle (Sadece bir kez)
    try {
      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      stopRealTimeLoop();
    } else if (state == AppLifecycleState.resumed) {
      startRealTimeLoop();
    }
  }

  // Staff listesini temizle (Logout/Delete durumunda)
  void clearStaff() {
    stopRealTimeLoop();
    _myStaff.clear();
  }

  // Personel İşe Al
  Future<bool> hireStaff(Staff staff) async {
    // Limit Kontrolü
    if (staff.role == StaffRole.sales || staff.role == StaffRole.buyer) {
      final count = _myStaff.where((s) => s.role == staff.role).length;
      if (count >= 2) {
        return false;
      }
    }

    // Staff userId güncelle (Hiring sırasında)
    final currentUser = await DatabaseHelper().getCurrentUser();
    if (currentUser == null) return false;

    // Yeni bir instance oluştur (copyWith olmadığı için yeniden oluşturuyoruz veya modelde copyWith olmalı)
    // Şimdilik modelde copyWith yok, o yüzden manuel ID set etme şansımız yok çünkü final.
    // Bu yüzden Staff modelini baştan oluşturacağız.

    Staff newStaff;
    if (staff is SalesAgent) {
      newStaff = SalesAgent(
        id: staff.id,
        userId: currentUser['id'],
        name: staff.name,
        salary: staff.salary,
        efficiency: staff.efficiency,
        morale: staff.morale,
        hiredDate: DateTime.now(), // İşe alım tarihi şimdi
        skill: staff.skill,
        speed: staff.speed,
        actionIntervalSeconds: staff.actionIntervalSeconds,
      );
    } else if (staff is BuyerAgent) {
      newStaff = BuyerAgent(
        id: staff.id,
        userId: currentUser['id'],
        name: staff.name,
        salary: staff.salary,
        efficiency: staff.efficiency,
        morale: staff.morale,
        hiredDate: DateTime.now(),
        targetBrands: staff.targetBrands,
        maxBudgetPerVehicle: staff.maxBudgetPerVehicle,
        skill: staff.skill,
        speed: staff.speed,
        actionIntervalSeconds: staff.actionIntervalSeconds,
      );
    } else {
      return false;
    }

    _myStaff.add(newStaff);
    await DatabaseHelper().addStaff(newStaff);
    return true;
  }

  // Personel Kov
  Future<bool> fireStaff(String staffId) async {
    _myStaff.removeWhere((s) => s.id == staffId);
    await DatabaseHelper().removeStaff(staffId);
    return true;
  }

  // Personel Durdur/Başlat
  Future<void> toggleStaffPause(String staffId) async {
    final staffIndex = _myStaff.indexWhere((s) => s.id == staffId);
    if (staffIndex == -1) return;

    final staff = _myStaff[staffIndex];
    staff.isPaused = !staff.isPaused;

    // DB Güncelle
    await DatabaseHelper().addStaff(staff); // Upsert

    // UI Güncelle
    _eventController.add('staff_update_${staff.id}');

    // Mesaj hazırla
    final msg = staff.isPaused
        ? 'staff.pause_success'.trParams({'name': staff.name})
        : 'staff.resume_success'.trParams({'name': staff.name});

    _eventController.add(msg);
  }

  // Günlük Maaşları Hesapla
  double calculateDailyWages() {
    double total = 0;
    for (var staff in _myStaff) {
      // Sadece aktif personel maaş alır (Pause olsa bile sözleşme devam ettiği için maaş işler)
      total += staff.salary;
    }
    return total;
  }

  // Günlük Maaşları Öde
  Future<void> processDailySalaries() async {
    // 1. App Active Check (Extra Safe)
    if (_simulatorTimer == null || !_simulatorTimer!.isActive) {
      debugPrint(
        'StaffService: Game is paused/inactive. Skipping salary payment.',
      );
      return;
    }

    if (_myStaff.isEmpty) return;

    final totalWages = calculateDailyWages();
    if (totalWages <= 0) return;

    final db = DatabaseHelper();
    final userMap = await db.getCurrentUser();
    if (userMap == null) return;

    final String userId = userMap['id'];
    final double currentBalance = (userMap['balance'] as num).toDouble();

    // 2. Balance Safeguard (Bankruptcy Protection)
    // Eğer bakiye yetersizse ödeme yapma
    if (currentBalance < totalWages) {
      debugPrint(
        'StaffService: Insufficient balance ($currentBalance < $totalWages). Skipping salary payment to prevent debt.',
      );
      // Opsiyonel: Kullanıcıya bildirilmesi gerekebilir ama şimdilik sessizce geçiyoruz.
      return;
    }

    // Bakiye kontrolü yapmaksızın düş, eksiye düşebilir (Borç) -> ARTIK YAPMIYORUZ
    final newBalance = currentBalance - totalWages;
    await db.updateUser(userId, {'balance': newBalance});

    // Gider olarak kaydet
    await ActivityService().logActivity(
      userId: userId,
      type: ActivityType.expense,
      title: 'staff.salary_payment_title'.tr(), // "Personel Maaş Ödemesi"
      description: 'staff.salary_payment_desc'.trParams({
        'count': _myStaff.length.toString(),
      }), // "{count} personel için günlük ödeme"
      amount: -totalWages,
      titleKey: 'staff.salary_payment_title',
      descriptionKey: 'staff.salary_payment_desc',
      descriptionParams: {'count': _myStaff.length.toString()},
    );

    // UI Güncelle
    _eventController.add(
      'staff_action_salary_paid',
    ); // ActivityScreen yenilenmesi için
  }

  // Günlük Satış Özeti için Stream
  final _eventController = StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventController.stream;

  Timer? _simulatorTimer;

  // Real-Time Simülasyonu Başlat
  void startRealTimeLoop() {
    if (_simulatorTimer != null && _simulatorTimer!.isActive) return;

    // Her saniye kontrol et
    _simulatorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkStaffActivity();
    });
  }

  void stopRealTimeLoop() {
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
  }

  static const int DAILY_TRANSACTION_LIMIT = 20;

  // Periyodik Kontrol
  void _checkStaffActivity() async {
    if (_myStaff.isEmpty) return;

    final db = DatabaseHelper();
    final userMap = await db.getCurrentUser();
    if (userMap == null) return;
    final String userId = userMap['id'];

    // 1. Sözleşme Süresi Kontrolü
    _checkExpiredContracts();

    // 2. Aktivite Kontrolü
    for (var staff in List<Staff>.from(_myStaff)) {
      // List.from ile kopya üzerinde dönüyoruz çünkü işlem sırasında silinebilir
      final now = DateTime.now();

      // Eğer personel duraklatıldıysa işlem yapma (Sadece contract süresi işler)
      if (staff.isPaused) continue;

      // Günlük Limit Kontrolü ve Sıfırlama
      if (staff.lastDailyActionDate == null ||
          staff.lastDailyActionDate!.day != now.day ||
          staff.lastDailyActionDate!.month != now.month ||
          staff.lastDailyActionDate!.year != now.year) {
        // Yeni bir gün, limiti sıfırla
        staff.dailyActionCount = 0;
        staff.lastDailyActionDate = now;
        // DB güncelle (Sadece tarih değiştiğinde kaydetmek iyi olur)
        await db.addStaff(staff);
      }

      // Limit dolduysa işlem yapma
      if (staff.dailyActionCount >= DAILY_TRANSACTION_LIMIT) continue;

      final difference = now.difference(staff.lastActionTime).inSeconds;

      // Süre dolduysa işlem yap
      if (difference >= staff.actionIntervalSeconds) {
        bool success = false;
        if (staff.role == StaffRole.buyer) {
          success = await _processBuyerAgent(
            staff as BuyerAgent,
            userId,
            db,
            userMap,
          );
        } else if (staff.role == StaffRole.sales) {
          success = await _processSalesAgent(staff as SalesAgent, userId, db);
        }

        // İşlem zamanını güncelle
        staff.lastActionTime = now;

        // İşlem başarılıysa sayacı artır
        if (success) {
          staff.dailyActionCount++;
          staff.lastDailyActionDate = now;
          await db.addStaff(staff); // Sayacı kaydet
        }

        // UI güncellemesi için stream'e bilgi at (Progress bar reset için)
        _eventController.add('staff_action_${staff.id}');
      }
    }
  }

  // Süresi dolan personelleri kontrol et ve çıkar
  void _checkExpiredContracts() {
    final now = DateTime.now();
    final expiredStaff = _myStaff.where((s) {
      final daysWorked = now.difference(s.hiredDate).inDays;
      return daysWorked >= CONTRACT_DURATION_DAYS;
    }).toList();

    for (var staff in expiredStaff) {
      fireStaff(staff.id); // Otomatik işten çıkar
      _eventController.add(
        'staff.contract_expired'.trParams({'name': staff.name}),
      );
      // Opsiyonel: Bildirim veya Aktivite geçmişine ekle
      // _activityService.log... (Şimdilik sadece snackbar/event ile yetinelim)
    }
  }

  Future<bool> _processSalesAgent(
    SalesAgent agent,
    String userId,
    DatabaseHelper db,
  ) async {
    // Satılabilir araçları getir
    List<dynamic> allVehicles = await db.getUserVehicles(userId);
    List<dynamic> availableVehicles = allVehicles.where((v) {
      // Sadece satılık olmayan, satılmamış ve PERSONEL tarafından alınmış araçları satabilir
      return !v.isListedForSale && !v.isSold && (v.isStaffPurchased == true);
    }).toList();

    if (availableVehicles.isEmpty) return false; // Satacak araç yok

    final result = agent.work();
    final success = await _handleSalesAgentWork(
      agent,
      result,
      availableVehicles,
      userId,
    );

    if (success) {
      // Snackbar kaldırıldı
      _eventController.add('staff_action_${agent.id}'); // Sadece UI update için
    }
    return success;
  }

  Future<bool> _processBuyerAgent(
    BuyerAgent agent,
    String userId,
    DatabaseHelper db,
    Map<String, dynamic> userMap,
  ) async {
    final currentBalance = (userMap['balance'] as num).toDouble();
    final result = agent.work();

    final success = await _handleBuyerAgentWork(
      agent,
      result,
      currentBalance,
      userId,
    );

    if (success) {
      _eventController.add('staff_action_${agent.id}');
    }
    return success;
  }

  // Aday Listesi Oluştur (GÜNCEL)
  List<Staff> generateCandidates(StaffRole role) {
    List<Staff> candidates = [];
    for (int i = 0; i < 3; i++) {
      String id =
          DateTime.now().millisecondsSinceEpoch.toString() + i.toString();
      String name = generateRandomName();
      double baseSalary = 0;

      // Rastgele Skill (0.30 - 0.70) - Maks %70
      double skill = 0.30 + (DateTime.now().microsecond % 41) / 100.0;

      // Rastgele Speed (10s - 30s arası interval) - Çok daha hızlı
      // Speed multiplier: 2.0 (yavaş) - 6.0 (hızlı)
      // Interval = 60 / speed. Örn: speed 6.0 -> 10 sn. speed 2.0 -> 30 sn.
      double speedMultiplier = 2.0 + (DateTime.now().microsecond % 400) / 100.0;
      int interval = (60 / speedMultiplier).round().clamp(10, 30);

      if (role == StaffRole.sales) {
        // Maaş Hesaplama (Hıza göre artış)
        baseSalary = 3000 + (skill * 5000) + (speedMultiplier * 2000);

        candidates.add(
          SalesAgent(
            id: id,
            userId: 'candidate', // Geçici ID, işe alınınca değişecek
            name: name,
            salary: baseSalary.roundToDouble(),
            hiredDate: DateTime.now(),
            skill: skill,
            speed: speedMultiplier,
            actionIntervalSeconds: interval,
          ),
        );
      } else if (role == StaffRole.buyer) {
        // Maaş Hesaplama
        baseSalary = 3500 + (skill * 6000) + (speedMultiplier * 2000);

        candidates.add(
          BuyerAgent(
            id: id,
            userId: 'candidate', // Geçici ID
            name: name,
            salary: baseSalary.roundToDouble(),
            hiredDate: DateTime.now(),
            skill: skill,
            speed: speedMultiplier,
            actionIntervalSeconds: interval,
          ),
        );
      }
    }
    return candidates;
  }

  Future<bool> _handleBuyerAgentWork(
    BuyerAgent agent,
    Map<String, dynamic> result,
    double currentBalance,
    String userId,
  ) async {
    // Şans Faktörü: Piyasa Bilgisi + Rastgelelik
    final double successChance = result['success_chance'] ?? 0.5;
    final double randomRoll = (DateTime.now().microsecond % 1000) / 1000.0;

    // Şansı artırıyoruz: 1.2 çarpanı (Daha agresif alım)
    final double adjustedChance = successChance * 1.2;

    if (randomRoll < adjustedChance) {
      // Araç Bulma: Gerçek market ilanlarından seç
      final marketService = MarketRefreshService();

      // Tüm aktif ilanları al (Normal + Fırsat)
      final activeVehicles = marketService.getActiveListings();
      final opportunityListings = marketService.getOpportunityListings();
      // Fırsat ilanlarından araçları çek
      final opportunityVehicles = opportunityListings
          .map((l) => l.vehicle)
          .toList();

      final allVehicles = [...activeVehicles, ...opportunityVehicles];

      if (allVehicles.isEmpty) {
        // allVehicles.isEmpty olmalı

        return false;
      }

      // Bütçeye uygun araçları filtrele (Max bütçe veya kullanıcı bakiyesi)
      final double budgetLimit = agent.maxBudgetPerVehicle > 0
          ? (agent.maxBudgetPerVehicle < currentBalance
                ? agent.maxBudgetPerVehicle
                : currentBalance)
          : currentBalance;

      final affordableVehicles = allVehicles
          .where((v) => v.price <= budgetLimit)
          .toList();

      if (affordableVehicles.isEmpty) {
        return false;
      }

      // Rastgele bir araç seç (İleride tercih edilen markaya göre de seçebilir)
      final randomIndex =
          DateTime.now().microsecond % affordableVehicles.length;
      final vehicle = affordableVehicles[randomIndex];

      // Fiyat Kontrolü
      double basePrice = vehicle.price;
      double discountMargin = result['discount_margin'] ?? 0.0;

      // Pazarlık Yap (Fiyatı düşür)
      double finalPrice = basePrice * (1.0 - discountMargin);

      // Bakiye yetiyor mu? (Tekrar check, pazarlık sonrası)
      if (currentBalance >= finalPrice) {
        final db = DatabaseHelper();

        // Satın Al
        final purchasedVehicle = await db.buyVehicleForUser(
          userId,
          vehicle,
          finalPrice,
          isOpportunity: true, // İstatistiklerde fırsat gibi görünsün
          isStaffPurchased: true, // Staff tarafından alındı
        );

        if (purchasedVehicle != null) {
          // İlanı marketten kaldır (Başkası alamasın)
          // Hangi listede olduğunu bilemediğimiz için her ikisinden de silmeyi dene
          marketService.removeListing(vehicle.id);
          marketService.removeOpportunityListing(vehicle.id);

          // Aktivite Kaydı
          // GÜNCELLEME: staffPurchase tipi kullanılıyor
          await ActivityService().logActivity(
            userId: userId,
            type: ActivityType.staffPurchase,
            title: 'staff.activity_purchase_title'.trParams({
              'name': '${vehicle.brand} ${vehicle.model}',
            }),
            description: '', // Açıklama gizlendi
            amount: -finalPrice, // Gider olduğu için negatif
            titleKey: 'staff.activity_purchase_title',
            titleParams: {'name': '${vehicle.brand} ${vehicle.model}'},
            descriptionKey: '',
          );

          return true;
        }
      } else {
        // Bakiye yetmedi (Pazarlığa rağmen)
      }
    } else {}
    return false;
  }

  Future<bool> _handleSalesAgentWork(
    SalesAgent agent,
    Map<String, dynamic> result,
    List<dynamic> availableVehicles,
    String userId,
  ) async {
    // Şans Faktörü: İkna kabiliyeti + Rastgelelik
    final double successChance = result['success_chance'] ?? 0.5;
    // Satış ihtimalini cezalandırmıyoruz, hatta bonus verebiliriz
    // 0.5 çarpanını kaldırdık -> 1.0 (veya 1.1)
    final double adjustedChance = successChance * 1.1;
    final double randomRoll = (DateTime.now().microsecond % 1000) / 1000.0;

    if (randomRoll < adjustedChance && availableVehicles.isNotEmpty) {
      // Satış Başarılı! Rastgele bir araç seç
      final randomIndex = DateTime.now().microsecond % availableVehicles.length;
      final vehicleToSell = availableVehicles[randomIndex];

      // Listeden çıkar (bu tur başkası satmasın)
      availableVehicles.removeAt(randomIndex);

      // Fiyat Hesaplama
      double basePrice = vehicleToSell.purchasePrice;
      // Eğer purchasePrice 0 ise (bi şekilde), varsayılan bir değer ata
      if (basePrice <= 0) basePrice = 500000;

      double negotiationBonus = result['bonus_margin'] ?? 0.0;
      // Minimum satış fiyatı alış fiyatı olsun, üzerine kar eklensin
      double finalPrice = basePrice * (1.05 + negotiationBonus); // %5 taban kar

      // Veritabanı İşlemleri
      final db = DatabaseHelper();

      // 1. Aracı satıldı olarak işaretle
      await db.sellUserVehicle(vehicleToSell.id, finalPrice);

      // 2. Kullanıcı bakiyesini güncelle
      final userMap = await db.getCurrentUser();
      if (userMap != null) {
        final currentBalance = (userMap['balance'] as num).toDouble();
        final newBalance = currentBalance + finalPrice; // Tüm para kasaya girer

        await db.updateUser(userId, {'balance': newBalance});

        // 3. Aktivite geçmişine kaydet
        // GÜNCELLEME: staffSale tipi kullanılıyor
        // Kar oranını hesapla
        final double basePriceForCalc = vehicleToSell.purchasePrice > 0
            ? vehicleToSell.purchasePrice
            : 1.0;
        final double profit = finalPrice - basePriceForCalc;
        final double profitRate = (profit / basePriceForCalc) * 100;

        await ActivityService().logActivity(
          userId: userId,
          type: ActivityType.staffSale,
          title: 'staff.activity_sale_title'.trParams({
            // ignore: prefer_interpolation_to_compose_strings
            'name': vehicleToSell.brand + ' ' + vehicleToSell.model,
          }),
          description: 'staff.profit_rate'.trParams({
            'rate': profitRate.toStringAsFixed(0),
          }),
          amount: finalPrice,
          titleKey: 'staff.activity_sale_title',
          titleParams: {
            // ignore: prefer_interpolation_to_compose_strings
            'name': vehicleToSell.brand + ' ' + vehicleToSell.model,
          },
          descriptionKey: 'staff.profit_rate',
          descriptionParams: {'rate': profitRate.toStringAsFixed(0)},
        );

        return true;
      }
    }
    return false;
  }

  // Rastgele İsim Üreteci
  String generateRandomName() {
    final names = [
      'Ahmet',
      'Mehmet',
      'Ayşe',
      'Fatma',
      'Ali',
      'Zeynep',
      'Can',
      'Elif',
      'Burak',
      'Ceren',
    ];
    final surnames = [
      'Yılmaz',
      'Kaya',
      'Demir',
      'Çelik',
      'Şahin',
      'Yıldız',
      'Öztürk',
      'Arslan',
      'Koç',
    ];
    names.shuffle();
    surnames.shuffle();
    return '${names.first} ${surnames.first}';
  }
}
