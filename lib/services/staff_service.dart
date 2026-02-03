import '../models/staff_model.dart';
import 'dart:async';
import 'database_helper.dart';
import 'localization_service.dart';
import 'game_time_service.dart';
import 'activity_service.dart';
import '../models/user_vehicle_model.dart';

class StaffService {
  static final StaffService _instance = StaffService._internal();
  factory StaffService() => _instance;
  StaffService._internal();

  // Geçici olarak bellek içi liste (İleride DB'ye taşınacak)
  List<Staff> _myStaff = [];
  bool _isListening = false; // Simülasyonun aktif olup olmadığını takip eder

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

  // Aday Listesi Oluştur
  List<Staff> generateCandidates(StaffRole role) {
    List<Staff> candidates = [];
    for (int i = 0; i < 3; i++) {
      String id =
          DateTime.now().millisecondsSinceEpoch.toString() + i.toString();
      String name = generateRandomName();
      double baseSalary = 0;
      int efficiency = 50 + (DateTime.now().microsecond % 40); // 50-90 arası

      if (role == StaffRole.sales) {
        // Rastgele yetenek dağılımı
        double negotiation =
            0.0 + (DateTime.now().microsecond % 20) / 100.0; // 0.0 - 0.20
        double persuasion =
            0.3 + (DateTime.now().microsecond % 50) / 100.0; // 0.3 - 0.8
        double speed =
            0.8 + (DateTime.now().microsecond % 120) / 100.0; // 0.8 - 2.0

        // Maaş Hesaplama (Statlara göre)
        baseSalary =
            2000 + (negotiation * 10000) + (persuasion * 5000) + (speed * 1000);

        candidates.add(
          SalesAgent(
            id: id,
            name: name,
            salary: baseSalary.roundToDouble(),
            efficiency: efficiency,
            hiredDate: DateTime.now(),
            negotiationSkill: negotiation,
            persuasion: persuasion,
            speed: speed,
          ),
        );
      } else if (role == StaffRole.buyer) {
        baseSalary = 3000 + (efficiency * 50);
        candidates.add(
          BuyerAgent(
            id: id,
            name: name,
            salary: baseSalary.roundToDouble(),
            efficiency: efficiency,
            hiredDate: DateTime.now(),
          ),
        );
      }
    }
    return candidates;
  }

  // Rastgele İsim Üreteci (Mock İçin)
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

  // Günlük Satış Özeti için Stream
  final _eventController = StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventController.stream;

  void startSimulation() {
    if (_isListening) return; // Zaten dinliyorsak tekrar ekleme

    // GameTimeService'e abone ol (Eğer değilsek)
    GameTimeService().addDayChangeListener(_onDayChange);
    _isListening = true;
    print("Staff Simulation Subscribed to GameTimeService.");
  }

  void _onDayChange(int oldDay, int newDay) {
    print("Game Day Changed ($oldDay -> $newDay). Running Staff Loop...");
    _runGameLoop();
  }

  void stopSimulation() {
    if (!_isListening) return;

    GameTimeService().removeDayChangeListener(_onDayChange);
    _isListening = false;
    print("Staff Simulation Unsubscribed from GameTimeService.");
  }

  void _runGameLoop() async {
    if (_myStaff.isEmpty) return;

    final db = DatabaseHelper();
    final userMap = await db.getCurrentUser();
    if (userMap == null) return;
    final String userId = userMap['id'];

    // 1. Maaş Kontrolü ve Ödeme
    final double dailyWages = calculateDailyWages();
    final currentBalance = (userMap['balance'] as num).toDouble();

    if (currentBalance < dailyWages) {
      // Maaşları ödeyecek bakiye yok! İstifa etsinler.
      _myStaff.clear();
      _eventController.add(
        'staff.staff_resigned'.tr(
          defaultValue:
              'Yetersiz bakiye nedeniyle tüm personeliniz istifa etti!',
        ),
      );
      return;
    }

    if (dailyWages > 0) {
      final newBalance = currentBalance - dailyWages;
      await db.updateUser(userId, {'balance': newBalance});
      print("Staff Wages Paid: -$dailyWages TL. New Balance: $newBalance TL");
    }

    // 2. Satılabilir araçları getir (Listede olmayan ve satılmamış)
    // Sahibinin garajındaki araçlar: Satılık değil + Satılmamış
    // Kiralık araçlar da satılabilir (istek üzerine)
    List<dynamic> allVehicles = await db.getUserVehicles(userId);
    List<dynamic> availableVehicles = allVehicles.where((v) {
      return !v.isListedForSale && !v.isSold;
    }).toList();

    int loopSalesCount = 0;
    bool hasSalesAgents = _myStaff.any((s) => s.role == StaffRole.sales);
    int initialAvailableCount = availableVehicles.length;

    for (var staff in _myStaff) {
      if (staff.role == StaffRole.sales) {
        // Eğer satılacak araç yoksa satış temsilcisi boşta bekler
        if (availableVehicles.isEmpty) continue;

        final result = staff.work();
        final success = await _handleSalesAgentWork(
          staff as SalesAgent,
          result,
          availableVehicles,
          userId,
        );
        if (success) loopSalesCount++;
      }
      // Diğer roller...
    }

    // --- Günlük Rapor (Snack Bar için) ---
    if (hasSalesAgents) {
      if (loopSalesCount > 0) {
        _eventController.add(
          'staff.daily_sales_success'.trParams({
            'count': loopSalesCount.toString(),
          }),
        );
      } else if (initialAvailableCount == 0) {
        _eventController.add(
          'staff.daily_sales_no_cars'.tr(
            defaultValue: 'Temsilcileriniz var ama satacak araç yok!',
          ),
        );
      } else {
        _eventController.add(
          'staff.daily_sales_none'.tr(
            defaultValue: 'Bugün hiç araç satışı olmadı.',
          ),
        );
      }
    }
  }

  Future<bool> _handleSalesAgentWork(
    SalesAgent agent,
    Map<String, dynamic> result,
    List<dynamic> availableVehicles,
    String userId,
  ) async {
    // Şans Faktörü: İkna kabiliyeti + Rastgelelik
    final double successChance = result['success_chance'] ?? 0.5;
    // Satış ihtimalini biraz dengeleyelim
    // User 5 game day beklediği halde satılmadığını belirtti.
    // Çarpanı 0.5'e (İkna gücünün yarısı) çıkaralım.
    final double adjustedChance = successChance * 0.5;
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
}
