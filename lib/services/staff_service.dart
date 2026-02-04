import '../models/staff_model.dart';
import 'dart:async';
import 'database_helper.dart';
import 'localization_service.dart';
// import '../services/game_time_service.dart';
import 'activity_service.dart';
import 'market_refresh_service.dart';
import '../models/user_vehicle_model.dart';

class StaffService {
  static final StaffService _instance = StaffService._internal();
  factory StaffService() => _instance;
  StaffService._internal();

  // Geçici olarak bellek içi liste (İleride DB'ye taşınacak)
  List<Staff> _myStaff = [];
  // Simülasyonun aktif olup olmadığını takip eder

  List<Staff> get myStaff => _myStaff;

  // Personel İşe Al
  Future<bool> hireStaff(Staff staff) async {
    // TODO: Bakiye kontrolü ve DB işlemi
    _myStaff.add(staff);
    return true;
  }

  // Personel Kov
  Future<bool> fireStaff(String staffId) async {
    _myStaff.removeWhere((s) => s.id == staffId);
    return true;
  }

  // Günlük Maaşları Hesapla
  double calculateDailyWages() {
    double total = 0;
    for (var staff in _myStaff) {
      total += staff.salary;
    }
    return total;
  }

  // Günlük Satış Özeti için Stream
  final _eventController = StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventController.stream;

  Timer? _simulatorTimer;

  // Real-Time Simülasyonu Başlat
  void startRealTimeLoop() {
    if (_simulatorTimer != null && _simulatorTimer!.isActive) return;

    print("Staff Real-Time Simulation Started.");
    // Her saniye kontrol et
    _simulatorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkStaffActivity();
    });
  }

  void stopRealTimeLoop() {
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
    print("Staff Real-Time Simulation Stopped.");
  }

  // Periyodik Kontrol
  void _checkStaffActivity() async {
    if (_myStaff.isEmpty) return;

    final db = DatabaseHelper();
    final userMap = await db.getCurrentUser();
    if (userMap == null) return;
    final String userId = userMap['id'];

    // Maaş ödemesi (Basitlik için hala günlük veya işlem başı olabilir ama şimdilik pas geçiyoruz)
    // Gerçek zamanlıda maaş belki dakikalık düşebilir ama şimdilik karmaşıklık katmayalım.

    for (var staff in _myStaff) {
      final now = DateTime.now();
      final difference = now.difference(staff.lastActionTime).inSeconds;

      // Süre dolduysa işlem yap
      if (difference >= staff.actionIntervalSeconds) {
        if (staff.role == StaffRole.buyer) {
          await _processBuyerAgent(staff as BuyerAgent, userId, db, userMap);
        } else if (staff.role == StaffRole.sales) {
          await _processSalesAgent(staff as SalesAgent, userId, db);
        }

        // İşlem zamanını güncelle
        staff.lastActionTime = now;
        // UI güncellemesi için stream'e bilgi at (Progress bar reset için)
        _eventController.add('staff_action_${staff.id}');
      }
    }
  }

  Future<void> _processSalesAgent(
    SalesAgent agent,
    String userId,
    DatabaseHelper db,
  ) async {
    // Satılabilir araçları getir
    List<dynamic> allVehicles = await db.getUserVehicles(userId);
    List<dynamic> availableVehicles = allVehicles.where((v) {
      return !v.isListedForSale && !v.isSold;
    }).toList();

    if (availableVehicles.isEmpty) return; // Satacak araç yok

    final result = agent.work();
    final success = await _handleSalesAgentWork(
      agent,
      result,
      availableVehicles,
      userId,
    );

    if (success) {
      _eventController.add(
        'staff.daily_sales_success'.trParams({'count': '1'}),
      );
    }
  }

  Future<void> _processBuyerAgent(
    BuyerAgent agent,
    String userId,
    DatabaseHelper db,
    Map<String, dynamic> userMap,
  ) async {
    final int currentVehicleCount = await db.getUserVehicleCount(userId);
    final int garageLimit = (userMap['garageLimit'] as num? ?? 10).toInt();

    if (currentVehicleCount >= garageLimit) {
      // Yer yok
      return;
    }

    final double currentBalance = (userMap['balance'] as num).toDouble();
    final result = agent.work();

    final success = await _handleBuyerAgentWork(
      agent,
      result,
      currentBalance,
      userId,
    );

    if (success) {
      _eventController.add(
        'staff.daily_purchase_success'.trParams({'count': '1'}),
      );
    }
  }

  // Aday Listesi Oluştur (GÜNCEL)
  List<Staff> generateCandidates(StaffRole role) {
    List<Staff> candidates = [];
    for (int i = 0; i < 3; i++) {
      String id =
          DateTime.now().millisecondsSinceEpoch.toString() + i.toString();
      String name = generateRandomName();
      double baseSalary = 0;

      // Rastgele Skill (0.5 - 0.95) - Daha yüksek yetenek
      double skill = 0.5 + (DateTime.now().microsecond % 45) / 100.0;

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
        print("Buyer ${agent.name}: Market is empty.");
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
        print(
          "Buyer ${agent.name}: No affordable vehicles found (Budget: ${budgetLimit.toStringAsFixed(0)}).",
        );
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
        );

        if (purchasedVehicle != null) {
          // İlanı marketten kaldır (Başkası alamasın)
          // Hangi listede olduğunu bilemediğimiz için her ikisinden de silmeyi dene
          marketService.removeListing(vehicle.id);
          marketService.removeOpportunityListing(vehicle.id);

          // Aktivite Kaydı
          await ActivityService().logVehiclePurchase(userId, purchasedVehicle);

          String logMsg =
              "🚙 ${agent.name} bir araç satın aldı!\nAraç: ${vehicle.brand} ${vehicle.model}\nFiyat: -${finalPrice.toStringAsFixed(0)} TL (Piyasa: ${basePrice.toStringAsFixed(0)})";
          print(logMsg);
          return true;
        }
      } else {
        // Bakiye yetmedi (Pazarlığa rağmen)
        print("Buyer ${agent.name} found car but insufficient funds.");
      }
    } else {
      print(
        "Buyer ${agent.name}: Search failed (Roll: $randomRoll > Chance: $adjustedChance)",
      );
    }
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
      double profit = finalPrice - basePrice;

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
        await ActivityService().logVehicleSale(
          userId,
          vehicleToSell as UserVehicle,
          finalPrice,
        );

        String logMsg =
            "🚗 ${agent.name} bir araç sattı!\nAraç: ${vehicleToSell.brand} ${vehicleToSell.model}\nBakiye: +${finalPrice.toStringAsFixed(0)} TL (Kâr: ${profit.toStringAsFixed(0)} TL)";
        print(logMsg);
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
