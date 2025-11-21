import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/vehicle_model.dart';
import 'game_time_service.dart';
import 'settings_helper.dart';

/// Pazar yenileme ve ilan yaşam döngüsü yönetim servisi
class MarketRefreshService {
  static final MarketRefreshService _instance = MarketRefreshService._internal();
  factory MarketRefreshService() => _instance;
  MarketRefreshService._internal();

  final GameTimeService _gameTime = GameTimeService();
  final Random _random = Random();
  
  // Aktif ilanlar (bellekte tutulan)
  final List<MarketListing> _activeListings = [];
  
  // Market çalkantı durumu
  bool _isMarketShakeActive = false;
  int _marketShakeDaysRemaining = 0;
  Map<String, double> _marketShakeAdjustments = {};
  
  // Marka spawn oranları (gerçek piyasa verisi)
  final Map<String, double> _brandSpawnRates = {
    'Renauva': 0.179,      // %17.9
    'Voltswagen': 0.144,   // %14.4
    'Fialto': 0.108,       // %10.8
    'Opexel': 0.089,       // %8.9
    'Bavora': 0.077,       // %7.7
    'Fortran': 0.070,      // %7.0
    'Mercurion': 0.064,    // %6.4
    'Hyundaro': 0.058,     // %5.8
    'Toyoto': 0.055,       // %5.5
    'Audira': 0.044,       // %4.4
    'Peugot': 0.042,       // %4.2
    'Hondaro': 0.037,      // %3.7
    'Skodra': 0.034,       // %3.4
    'Citronix': 0.030,     // %3.0
  };
  
  // Model spawn oranları (marka -> model -> oran)
  final Map<String, Map<String, double>> _modelSpawnRates = {
    'Renauva': {
      'Slim': 0.3782,      // Clio - %37.82
      'Magna': 0.3443,     // Megane - %34.43
      'Flow': 0.1349,      // Fluence - %13.49
      'Signa': 0.1150,     // Symbol - %11.50
      'Tallion': 0.0273,   // Taliant - %2.73
    },
    // Diğer markalar için varsayılan olarak eşit dağılım kullanılacak
    'Bavora': {},
    'Mercurion': {},
    'Audira': {},
    'Toyoto': {},
    'Voltswagen': {},
    'Fortran': {},
    'Peugot': {},
    'Hondaro': {},
    'Hyundaro': {},
    'Skodra': {},
    'Citronix': {},
    'Fialto': {},
    'Opexel': {},
  };
  
  // Marka-model eşleşmeleri (geriye dönük uyumluluk için)
  final Map<String, List<String>> _modelsByBrand = {
    'Renauva': ['Slim', 'Magna', 'Flow', 'Signa', 'Tallion'],
    'Bavora': ['316i', '318i', '320i', '520d', 'X3', 'X5'],
    'Mercurion': ['C180', 'C200', 'E200', 'E220d', 'GLE', 'GLA'],
    'Audira': ['A3', 'A4', 'A6', 'Q3', 'Q5', 'Q7'],
    'Toyoto': ['Corolla', 'Camry', 'RAV4', 'C-HR', 'Yaris'],
    'Voltswagen': ['Golf', 'Polo', 'Passat', 'Tiguan', 'T-Roc'],
    'Fortran': ['Focus', 'Fiesta', 'Mondeo', 'Kuga', 'Puma'],
    'Peugot': ['208', '308', '3008', '5008', '2008'],
    'Hondaro': ['Civic', 'Accord', 'CR-V', 'Jazz', 'HR-V'],
    'Hyundaro': ['i20', 'i30', 'Tucson', 'Kona', 'Elantra'],
    'Skodra': ['Fabia', 'Octavia', 'Superb', 'Karoq', 'Kodiaq'],
    'Citronix': ['C3', 'C4', 'C5 Aircross', 'Berlingo', 'C-Elysée'],
    'Fialto': ['Egea', '500', 'Tipo', 'Panda', 'Doblo'],
    'Opexel': ['Corsa', 'Astra', 'Insignia', 'Crossland', 'Grandland'],
  };

  // Sabit veriler
  final List<String> _cities = [
    'İstanbul', 'Ankara', 'İzmir', 'Antalya', 'Bursa',
    'Adana', 'Gaziantep', 'Konya', 'Mersin', 'Kayseri'
  ];
  
  final List<String> _colors = [
    'Beyaz', 'Siyah', 'Gri', 'Kırmızı', 'Mavi',
    'Gümüş', 'Kahverengi', 'Yeşil'
  ];
  
  final List<String> _fuelTypes = ['Benzin', 'Dizel', 'Hybrid', 'Elektrik'];
  final List<String> _transmissions = ['Manuel', 'Otomatik'];
  final List<String> _engineSizes = ['1.0', '1.2', '1.4', '1.6', '1.8', '2.0', '2.2', '2.5', '3.0'];
  final List<String> _driveTypes = ['Önden', 'Arkadan', '4x4'];
  final List<String> _bodyTypes = ['Sedan', 'Hatchback', 'SUV', 'Coupe', 'Station Wagon', 'MPV'];
  final List<String> _sellerTypes = ['Sahibinden', 'Galeriden'];
  
  // 2025 model yılı tavan fiyatları (brand -> model -> fiyat)
  final Map<String, Map<String, double>> _basePrices2025 = {
    'Renauva': {
      'Slim': 1500000.0,
      // Diğer modeller eklenecek
    },
    // Diğer markalar eklenecek
  };
  
  // Model-spesifik teknik özellik kuralları
  final Map<String, Map<String, dynamic>> _modelSpecs = {
    'Renauva_Slim': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2018], 'types': ['Sedan', 'Hatchback']},
          {'years': [2019, 2025], 'types': ['Hatchback']},
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Benzin+LPG']},
          {'years': [2010, 2020], 'types': ['Dizel']},
          {'years': [2020, 2025], 'types': ['Hybrid']},
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 2010-2025 hepsi
      'driveType': 'Önden', // Sabit
      'engineSize': {'min': 0.9, 'max': 1.6}, // 898cc - 1598cc
      'horsepower': {'min': 65, 'max': 145},
    },
  };

  /// Servisi başlat
  Future<void> initialize() async {
    debugPrint('🏪 MarketRefreshService initializing...');
    
    // İlk pazar oluştur
    await _generateInitialMarket();
    
    // Gün değişim listener'ı ekle
    _gameTime.addDayChangeListener(_onDayChange);
    
    debugPrint('✅ MarketRefreshService initialized with ${_activeListings.length} listings');
  }

  /// Gün değişiminde çağrılır
  void _onDayChange(int oldDay, int newDay) {
    debugPrint('📅 Market refresh triggered (Day $oldDay → $newDay)');
    _refreshMarket();
  }

  /// İlk pazarı oluştur (700-1200 ilan)
  Future<void> _generateInitialMarket() async {
    final totalListings = 700 + _random.nextInt(501); // 700-1200
    debugPrint('🏗️ Generating initial market: $totalListings listings');
    
    _activeListings.clear();
    
    for (var brandEntry in _brandSpawnRates.entries) {
      final brand = brandEntry.key;
      final spawnRate = brandEntry.value;
      final count = (totalListings * spawnRate).round();
      
      for (int i = 0; i < count; i++) {
        final listing = _generateListing(brand);
        _activeListings.add(listing);
      }
    }
    
    debugPrint('✅ Initial market generated: ${_activeListings.length} listings');
  }

  /// Pazarı yenile (günlük)
  void _refreshMarket() {
    final currentDay = _gameTime.getCurrentDay();
    
    // 1) Süresi dolan ilanları bul ve kaldır
    final expiredListings = _activeListings.where((listing) {
      return listing.expiryDay <= currentDay;
    }).toList();
    
    if (expiredListings.isNotEmpty) {
      debugPrint('🗑️ Removing ${expiredListings.length} expired listings');
      _activeListings.removeWhere((listing) => expiredListings.contains(listing));
    }
    
    // 2) Pazar çalkantısını kontrol et ve uygula
    _updateMarketShake();
    
    // 3) Yeni ilanlar oluştur (kaybolan ilan sayısı kadar)
    final newListingsNeeded = expiredListings.length;
    if (newListingsNeeded > 0) {
      debugPrint('➕ Generating $newListingsNeeded new listings');
      _generateNewListings(newListingsNeeded);
    }
    
    debugPrint('✅ Market refreshed. Total listings: ${_activeListings.length}');
  }

  /// Pazar çalkantısını güncelle
  void _updateMarketShake() {
    // Aktif çalkantı varsa sayacı azalt
    if (_isMarketShakeActive) {
      _marketShakeDaysRemaining--;
      if (_marketShakeDaysRemaining <= 0) {
        debugPrint('🔄 Market shake ended. Returning to normal.');
        _isMarketShakeActive = false;
        _marketShakeAdjustments.clear();
      }
    }
    
    // Yeni çalkantı başlatma kontrolü (%10 ihtimal)
    if (!_isMarketShakeActive && _random.nextDouble() < 0.10) {
      debugPrint('⚠️ Market shake started!');
      _isMarketShakeActive = true;
      _marketShakeDaysRemaining = 1 + _random.nextInt(2); // 1-2 gün
      
      // Her marka için -5% ile +5% arası ayarlama
      for (var brand in _brandSpawnRates.keys) {
        final adjustment = (_random.nextDouble() * 0.10) - 0.05; // -5% to +5%
        _marketShakeAdjustments[brand] = adjustment;
      }
      
      debugPrint('   Duration: $_marketShakeDaysRemaining days');
    }
  }

  /// Yeni ilanlar oluştur
  void _generateNewListings(int count) {
    for (int i = 0; i < count; i++) {
      // Spawn oranına göre marka seç (çalkantı göz önünde bulundurularak)
      final brand = _selectRandomBrand();
      final listing = _generateListing(brand);
      _activeListings.add(listing);
    }
  }

  /// Spawn oranına göre rastgele marka seç
  String _selectRandomBrand() {
    final rand = _random.nextDouble();
    double cumulative = 0.0;
    
    for (var entry in _brandSpawnRates.entries) {
      var rate = entry.value;
      
      // Pazar çalkantısı uygulanıyorsa ayarlama yap
      if (_isMarketShakeActive && _marketShakeAdjustments.containsKey(entry.key)) {
        rate += _marketShakeAdjustments[entry.key]!;
        rate = rate.clamp(0.01, 0.30); // Min %1, max %30
      }
      
      cumulative += rate;
      if (rand < cumulative) {
        return entry.key;
      }
    }
    
    return _brandSpawnRates.keys.first; // Fallback
  }
  
  /// Spawn oranına göre rastgele model seç
  String _selectRandomModel(String brand) {
    final modelRates = _modelSpawnRates[brand];
    
    // Eğer bu marka için spawn oranları tanımlanmışsa, o oranları kullan
    if (modelRates != null && modelRates.isNotEmpty) {
      final rand = _random.nextDouble();
      double cumulative = 0.0;
      
      for (var entry in modelRates.entries) {
        cumulative += entry.value;
        if (rand < cumulative) {
          return entry.key;
        }
      }
      
      // Fallback (oranlar toplamı 1 değilse)
      return modelRates.keys.first;
    }
    
    // Spawn oranı tanımlanmamışsa, eşit dağılım kullan
    final models = _modelsByBrand[brand] ?? ['Model'];
    return models[_random.nextInt(models.length)];
  }

  /// Yeni bir ilan oluştur (gerçekçi parametrelerle)
  MarketListing _generateListing(String brand) {
    // Model seç (spawn oranlarına göre veya eşit dağılım)
    final model = _selectRandomModel(brand);
    
    // Gerçekçi yıl dağılımı (2015-2024, ağırlıklı son 5 yıl)
    final year = _generateRealisticYear();
    
    // Gerçekçi kilometre dağılımı
    final mileage = _generateRealisticMileage();
    
    // Model-spesifik teknik özellikler al (varsa)
    final specKey = '${brand}_$model';
    final specs = _modelSpecs[specKey];
    
    // Diğer özellikler (model-spesifik veya genel)
    final fuelType = specs != null 
      ? _getSpecificFuelType(specs, year) 
      : _fuelTypes[_random.nextInt(_fuelTypes.length)];
      
    final transmission = specs != null
      ? _getSpecificTransmission(specs, year)
      : _transmissions[_random.nextInt(_transmissions.length)];
      
    final bodyType = specs != null
      ? _getSpecificBodyType(specs, year)
      : _bodyTypes[_random.nextInt(_bodyTypes.length)];
      
    final driveType = specs != null && specs['driveType'] != null
      ? specs['driveType'] as String
      : _driveTypes[_random.nextInt(_driveTypes.length)];
      
    final engineSize = specs != null && specs['engineSize'] != null
      ? _getSpecificEngineSize(specs)
      : _engineSizes[_random.nextInt(_engineSizes.length)];
      
    final horsepower = specs != null && specs['horsepower'] != null
      ? _getSpecificHorsepower(specs)
      : 100 + _random.nextInt(300);
    
    final hasAccidentRecord = _random.nextInt(10) < 2; // %20
    final sellerType = _sellerTypes[_random.nextInt(_sellerTypes.length)];
    
    // Fiyat oluştur (yeni sistem)
    final price = _generateRealisticPrice(
      brand: brand,
      model: model,
      year: year,
      mileage: mileage,
      fuelType: fuelType,
      transmission: transmission,
      hasAccidentRecord: hasAccidentRecord,
      sellerType: sellerType,
    );
    
    // Araç objesi oluştur
    final vehicle = Vehicle.create(
      brand: brand,
      model: model,
      year: year,
      mileage: mileage,
      price: price,
      location: _cities[_random.nextInt(_cities.length)],
      color: _colors[_random.nextInt(_colors.length)],
      fuelType: fuelType,
      transmission: transmission,
      condition: 'İkinci El',
      engineSize: engineSize,
      driveType: driveType,
      hasWarranty: _random.nextBool(),
      hasAccidentRecord: hasAccidentRecord,
      description: _generateDescription(),
      bodyType: bodyType,
      horsepower: horsepower,
      sellerType: sellerType,
    );
    
    // Yaşam süresi hesapla (skora göre)
    final lifespan = _calculateListingLifespan(vehicle.score, price);
    
    return MarketListing(
      vehicle: vehicle,
      createdDay: _gameTime.getCurrentDay(),
      expiryDay: _gameTime.getCurrentDay() + lifespan,
    );
  }

  /// Model-spesifik yakıt tipi seç
  String _getSpecificFuelType(Map<String, dynamic> specs, int year) {
    final fuelData = specs['fuelTypes'];
    if (fuelData == null) return _fuelTypes[_random.nextInt(_fuelTypes.length)];
    
    final List<dynamic> ranges = fuelData['ranges'] as List;
    List<String> availableTypes = [];
    
    for (var range in ranges) {
      final years = range['years'] as List;
      if (year >= years[0] && year <= years[1]) {
        availableTypes.addAll((range['types'] as List).cast<String>());
      }
    }
    
    if (availableTypes.isEmpty) return 'Benzin';
    return availableTypes[_random.nextInt(availableTypes.length)];
  }
  
  /// Model-spesifik vites tipi seç
  String _getSpecificTransmission(Map<String, dynamic> specs, int year) {
    final transList = specs['transmissions'];
    if (transList == null) return _transmissions[_random.nextInt(_transmissions.length)];
    
    final List<String> types = (transList as List).cast<String>();
    return types[_random.nextInt(types.length)];
  }
  
  /// Model-spesifik kasa tipi seç
  String _getSpecificBodyType(Map<String, dynamic> specs, int year) {
    final bodyData = specs['bodyTypes'];
    if (bodyData == null) return _bodyTypes[_random.nextInt(_bodyTypes.length)];
    
    final List<dynamic> ranges = bodyData['ranges'] as List;
    List<String> availableTypes = [];
    
    for (var range in ranges) {
      final years = range['years'] as List;
      if (year >= years[0] && year <= years[1]) {
        availableTypes.addAll((range['types'] as List).cast<String>());
      }
    }
    
    if (availableTypes.isEmpty) return 'Sedan';
    return availableTypes[_random.nextInt(availableTypes.length)];
  }
  
  /// Model-spesifik motor hacmi seç
  String _getSpecificEngineSize(Map<String, dynamic> specs) {
    final engineData = specs['engineSize'] as Map?;
    if (engineData == null) return _engineSizes[_random.nextInt(_engineSizes.length)];
    
    final double min = (engineData['min'] as num).toDouble();
    final double max = (engineData['max'] as num).toDouble();
    
    // 0.9 - 1.6 arasında rastgele seç (yaygın motor hacimleri)
    final List<double> commonSizes = [0.9, 1.0, 1.2, 1.3, 1.4, 1.5, 1.6];
    final validSizes = commonSizes.where((s) => s >= min && s <= max).toList();
    
    if (validSizes.isEmpty) return min.toStringAsFixed(1);
    
    return validSizes[_random.nextInt(validSizes.length)].toStringAsFixed(1);
  }
  
  /// Model-spesifik beygir gücü seç
  int _getSpecificHorsepower(Map<String, dynamic> specs) {
    final hpData = specs['horsepower'] as Map?;
    if (hpData == null) return 100 + _random.nextInt(300);
    
    final int min = hpData['min'] as int;
    final int max = hpData['max'] as int;
    
    return min + _random.nextInt(max - min + 1);
  }

  /// İlan yaşam süresini hesapla (oyun günü cinsinden)
  int _calculateListingLifespan(int score, double price) {
    // Skor ne kadar yüksekse (iyi anlaşma), o kadar hızlı satılır
    
    if (score >= 75) {
      // Çok ucuz/iyi anlaşma: 1-3 gün
      return 1 + _random.nextInt(3);
    } else if (score >= 50) {
      // Orta fiyatlı: 2-5 gün
      return 2 + _random.nextInt(4);
    } else {
      // Pahalı: 4-8 gün
      return 4 + _random.nextInt(5);
    }
  }

  /// Gerçekçi yıl oluştur (ağırlıklı)
  int _generateRealisticYear() {
    final rand = _random.nextDouble();
    final currentYear = DateTime.now().year;
    
    if (rand < 0.40) {
      // %40: Son 3 yıl (2022-2024)
      return currentYear - _random.nextInt(3);
    } else if (rand < 0.70) {
      // %30: 4-7 yaşında (2017-2021)
      return currentYear - (4 + _random.nextInt(4));
    } else {
      // %30: 8+ yaşında (2015 ve öncesi)
      return currentYear - (8 + _random.nextInt(10));
    }
  }

  /// Gerçekçi kilometre oluştur
  int _generateRealisticMileage() {
    final rand = _random.nextDouble();
    
    if (rand < 0.20) {
      // %20: Düşük KM (10k-50k)
      return 10000 + _random.nextInt(40000);
    } else if (rand < 0.75) {
      // %55: Orta KM (50k-150k)
      return 50000 + _random.nextInt(100000);
    } else {
      // %25: Yüksek KM (150k-300k)
      return 150000 + _random.nextInt(150000);
    }
  }

  /// Gerçekçi fiyat oluştur
  double _generateRealisticPrice({
    required String brand,
    required String model,
    required int year,
    required int mileage,
    required String fuelType,
    required String transmission,
    required bool hasAccidentRecord,
    required String sellerType,
  }) {
    // Base price al (2025 tavan fiyatı)
    double basePrice = _basePrices2025[brand]?[model] ?? 500000.0;
    
    // YIL FAKTÖRÜ (2025'den geriye gidildikçe değer düşer)
    final age = 2025 - year;
    double yearFactor = 1.0;
    if (age == 0) {
      yearFactor = 1.0; // 2025 model
    } else if (age <= 2) {
      yearFactor = 0.90 - (age * 0.05); // 2023-2024: %90-85
    } else if (age <= 5) {
      yearFactor = 0.80 - ((age - 2) * 0.08); // 2020-2022: %80-56
    } else if (age <= 10) {
      yearFactor = 0.56 - ((age - 5) * 0.06); // 2015-2019: %56-26
    } else {
      yearFactor = 0.26 - ((age - 10) * 0.03); // 2014 ve öncesi
    }
    yearFactor = yearFactor.clamp(0.10, 1.0);
    
    // KİLOMETRE FAKTÖRÜ
    double kmFactor = 1.0;
    if (mileage <= 20000) {
      kmFactor = 1.0; // Sıfır gibi
    } else if (mileage <= 50000) {
      kmFactor = 0.95;
    } else if (mileage <= 100000) {
      kmFactor = 0.85;
    } else if (mileage <= 150000) {
      kmFactor = 0.75;
    } else if (mileage <= 200000) {
      kmFactor = 0.65;
    } else if (mileage <= 250000) {
      kmFactor = 0.55;
    } else {
      kmFactor = 0.45;
    }
    
    // YAKIT TİPİ FAKTÖRÜ
    double fuelFactor = 1.0;
    if (fuelType == 'Dizel') {
      fuelFactor = 1.10; // Dizel %10 daha değerli
    } else if (fuelType == 'Hybrid') {
      fuelFactor = 1.15; // Hybrid %15 daha değerli
    } else if (fuelType == 'Elektrik') {
      fuelFactor = 1.20; // Elektrik %20 daha değerli
    } else {
      fuelFactor = 1.0; // Benzin
    }
    
    // VİTES FAKTÖRÜ
    double transFactor = transmission == 'Otomatik' ? 1.08 : 1.0; // Otomatik %8 daha değerli
    
    // HASAR FAKTÖRÜ
    double accidentFactor = hasAccidentRecord ? 0.85 : 1.0; // Hasarlı %15 düşük
    
    // SATICI TİPİ FAKTÖRÜ (Galeriden biraz daha pahalı)
    double sellerFactor = sellerType == 'Galeriden' ? 1.05 : 1.0; // Galeri %5 daha pahalı
    
    // GENEL HESAPLAMa
    double finalPrice = basePrice * yearFactor * kmFactor * fuelFactor * transFactor * accidentFactor * sellerFactor;
    
    // Rastgele varyasyon ±8% (pazar dinamikleri)
    final variation = ((_random.nextDouble() * 0.16) - 0.08);
    finalPrice = finalPrice * (1 + variation);
    
    return finalPrice.clamp(50000.0, basePrice * 1.1);
  }

  /// Açıklama oluştur
  String _generateDescription() {
    final descriptions = [
      'Tek elden, bakımlı ve temiz kullanım.',
      'Hasarsız, bakımlı ve sorunsuz bir araç.',
      'Garaj arabası. Hep düzenli kullanılmış.',
      'Aileden satılık araç. Sorunsuz bir araçtır.',
      'Sıfır km\'den beri tüm bakımları yapılmıştır.',
      'İkinci el ama sıfır gibi. Tramer kaydı temiz.',
      'Ekonomik ve güvenilir araç.',
      'Değişensiz, boyasız ve hasarsız araç.',
    ];
    return descriptions[_random.nextInt(descriptions.length)];
  }

  /// Aktif ilanları al (marka filtrelemesi ile)
  List<Vehicle> getActiveListings({String? brand}) {
    if (brand == null) {
      return _activeListings.map((l) => l.vehicle).toList();
    }
    return _activeListings
        .where((l) => l.vehicle.brand == brand)
        .map((l) => l.vehicle)
        .toList();
  }

  /// Toplam aktif ilan sayısı
  int get totalListings => _activeListings.length;

  /// Pazar çalkantısı aktif mi?
  bool get isMarketShakeActive => _isMarketShakeActive;

  /// Servisi temizle
  void dispose() {
    _gameTime.removeDayChangeListener(_onDayChange);
    _activeListings.clear();
  }
}

/// Pazar ilanı wrapper
class MarketListing {
  final Vehicle vehicle;
  final int createdDay;  // Hangi oyun gününde oluşturuldu
  final int expiryDay;   // Hangi oyun gününde sona erecek

  MarketListing({
    required this.vehicle,
    required this.createdDay,
    required this.expiryDay,
  });

  /// İlan ne kadar gün daha aktif?
  int daysRemaining(int currentDay) => (expiryDay - currentDay).clamp(0, 999);

  /// İlan süresi doldu mu?
  bool isExpired(int currentDay) => currentDay >= expiryDay;
}

