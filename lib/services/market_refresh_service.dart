import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/vehicle_model.dart';
import 'localization_service.dart';
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
    'Volkstar': 0.144,   // %14.4
    'Fialto': 0.108,       // %10.8
    'Oplon': 0.089,       // %8.9
    'Bavora': 0.077,       // %7.7
    'Fortran': 0.070,      // %7.0
    'Mercurion': 0.064,    // %6.4
    'Hundar': 0.058,     // %5.8
    'Koyoro': 0.055,       // %5.5
    'Audira': 0.044,       // %4.4
    'Hanto': 0.037,      // %3.7
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
    'Volkstar': {
      'Paso': 0.40,        //  - %40
      'Tenis': 0.25,       // Golf - %25
      'Colo': 0.22,        // Polo - %22
      'Jago': 0.13,        // Jetta - %13
    },
    'Fialto': {
      'Agna': 0.7145,      // Egea - %71.45 (HACIM KRALI!)
      'Lagua': 0.2280,     // Linea - %22.80
      'Zorno': 0.0572,     // Punto - %5.72
    },
    'Oplon': {
      'Tasra': 0.55,       // Astra - %55
      'Lorisa': 0.323,     // Corsa - %32.3
      'Mornitia': 0.127,   // Insignia - %12.7
    },
    'Bavora': {
      'C Serisi': 0.40,    // 3 Serisi - %40
      'E Serisi': 0.25,    // 5 Serisi - %25
      'A Serisi': 0.22,    // 1 Serisi - %22
      'D Serisi': 0.13,    // 4 Serisi - %13
    },
    'Fortran': {
      'Odak': 0.5908,      // Focus - %59.08
      'Vista': 0.2169,     // Fiesta - %21.69
      'Avger': 0.1032,     // Ranger - %10.32
      'Tupa': 0.0891,      // Kuga - %8.91
    },
    'Mercurion': {
      '3 Serisi': 0.4218,  // C-Class - %42.18
      '5 Serisi': 0.2840,  // E-Class - %28.40
      '1 Serisi': 0.1019,  // A-Class - %10.19
      'GJE': 0.0998,       // CLA - %9.98
      '8 Serisi': 0.0926,  // G-Class - %9.26
    },
    'Hundar': {
      'A10': 0.5215,       // i20 - %52.15
      'Tecent Red': 0.1925, // Accent Blue - %19.25
      'Tecent White': 0.1095, // Accent Era - %10.95
      'A20': 0.0995,       // i30 - %9.95
      'Kascon': 0.0769,    // Tucson - %7.69
    },
    'Koyoro': {
      'Airoko': 0.8193,    // Corolla - %81.93
      'Lotus': 0.1165,     // Auris - %11.65
      'Karma': 0.0643,     // Yaris - %6.43
    },
    'Audira': {
      'B3': 0.4505,        // A3 - %45.05
      'B4': 0.2375,        // A4 - %23.75
      'B6': 0.2087,        // A6 - %20.87
      'B5': 0.1033,        // A5 - %10.33
    },
    'Hanto': {
      'Vice': 0.85,        // Civic - %85
      'VHL': 0.11,         // CR-V - %11
      'Caz': 0.04,         // Jazz - %4
    },
    // Diğer markalar için varsayılan olarak eşit dağılım kullanılacak
    'Fialto': {},
    'Oplon': {},
  };
  
  // Marka-model eşleşmeleri (geriye dönük uyumluluk için)
  final Map<String, List<String>> _modelsByBrand = {
    'Renauva': ['Slim', 'Magna', 'Flow', 'Signa', 'Tallion'],
    'Volkstar': ['Paso', 'Tenis', 'Colo', 'Jago'],
    'Fialto': ['Agna', 'Lagua', 'Zorno'],
    'Oplon': ['Tasra', 'Lorisa', 'Mornitia'],
    'Bavora': ['C Serisi', 'E Serisi', 'A Serisi', 'D Serisi'],
    'Fortran': ['Odak', 'Vista', 'Avger', 'Tupa'],
    'Mercurion': ['3 Serisi', '5 Serisi', '1 Serisi', 'GJE', '8 Serisi'],
    'Hundar': ['A10', 'Tecent Red', 'Tecent White', 'A20', 'Kascon'],
    'Koyoro': ['Airoko', 'Lotus', 'Karma'],
    'Audira': ['B3', 'B4', 'B6', 'B5'],
    'Hanto': ['Vice', 'VHL', 'Caz'],
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
  
  final List<String> _fuelTypes = ['Benzin', 'Dizel', 'Hybrid', /* 'Elektrik' */];
  final List<String> _transmissions = ['Manuel', 'Otomatik'];
  final List<String> _engineSizes = ['1.0', '1.2', '1.4', '1.6', '1.8', '2.0', '2.2', '2.5', '3.0'];
  final List<String> _driveTypes = ['Önden', 'Arkadan', '4x4'];
  final List<String> _bodyTypes = ['Sedan', 'Hatchback', 'SUV', 'Coupe', 'Station Wagon', 'MPV'];
  final List<String> _sellerTypes = ['Sahibinden', 'Galeriden'];
  
  // 2025 model yılı tavan fiyatları (brand -> model -> fiyat)
  final Map<String, Map<String, double>> _basePrices2025 = {
    'Renauva': {
      'Slim': 1450000.0,    // Clio V (Icon, Touch, Esprit Alpine) - ₺1.200.000-₺1.450.000 tavan
      'Magna': 1850000.0,   // Megane IV Sedan/HB (Icon, GT-Line) - ₺1.500.000-₺1.850.000 tavan
      'Flow': 825000.0,     // Fluence (Üretim durdu, 2014-2016 en üst) - ₺700.000-₺825.000 tavan
      'Signa': 875000.0,    // Symbol (2016-2020 Joy/Touch Plus) - ₺750.000-₺875.000 tavan
      'Tallion': 1050000.0, // Taliant (2024-2025 Touch Plus) - ₺900.000-₺1.050.000 tavan
    },
    'Volkstar': {
      'Paso': 2200000.0,    // Passat B8/B8.5 (Highline, R-Line) - ₺1.800.000-₺2.200.000 tavan
      'Tenis': 1800000.0,   // Golf VIII (R-Line, Highline) - ₺1.400.000-₺1.800.000 tavan
      'Colo': 1300000.0,    // Polo (Comfortline/Highline) - ₺1.050.000-₺1.300.000 tavan
      'Jago': 1150000.0,    // Jetta (Üretim durdu, 2016-2018 Highline) - ₺950.000-₺1.150.000 tavan
    },
    'Fialto': {
      'Agna': 1250000.0,    // Egea (Lounge, Limited, Hibrit) - ₺1.050.000-₺1.250.000 tavan
      'Lagua': 650000.0,    // Linea (Üretim durdu, 2014-2015 Emotion Plus) - ₺500.000-₺650.000 tavan
      'Zorno': 580000.0,    // Punto (Üretim durdu, 2014-2015 Lounge) - ₺450.000-₺580.000 tavan
    },
    'Oplon': {
      'Tasra': 1700000.0,   // Astra L (Ultimate, Elegance) - ₺1.350.000-₺1.700.000 tavan
      'Lorisa': 1200000.0,  // Corsa F (Ultimate, Elegance) - ₺950.000-₺1.200.000 tavan
      'Mornitia': 2000000.0, // Insignia B (Ultimate, Excellence) - ₺1.600.000-₺2.000.000 tavan
    },
    'Bavora': {
      'C Serisi': 3500000.0,  // 3 Serisi G20 (M Sport, Luxury Line) - ₺2.500.000-₺3.500.000 tavan
      'E Serisi': 5000000.0,  // 5 Serisi G30/G60 (M Sport, Executive) - ₺3.500.000-₺5.000.000 tavan
      'A Serisi': 1850000.0,  // 1 Serisi F40 (M Sport) - ₺1.500.000-₺1.850.000 tavan
      'D Serisi': 4000000.0,  // 4 Serisi G22/G26 (M Sport, Cabrio) - ₺2.800.000-₺4.000.000 tavan
    },
    'Fortran': {
      'Odak': 1500000.0,      // Focus IV (Titanium, ST-Line) - ₺1.200.000-₺1.500.000 tavan
      'Vista': 1150000.0,     // Fiesta VIII (ST-Line, Titanium) - ₺900.000-₺1.150.000 tavan
      'Avger': 4500000.0,     // Ranger (Wildtrak, Bi-Turbo) - ₺2.500.000-₺4.500.000 tavan (Raptor daha yüksek!)
      'Tupa': 2000000.0,      // Kuga III (Vignale, Hibrit) - ₺1.500.000-₺2.000.000 tavan
    },
    'Mercurion': {
      '3 Serisi': 4000000.0,  // C-Class W206 (AMG Line, Exclusive, Hibrit) - ₺2.800.000-₺4.000.000 tavan
      '5 Serisi': 5500000.0,  // E-Class W213 (AMG Line, Designo) - ₺3.800.000-₺5.500.000 tavan
      '1 Serisi': 2200000.0,  // A-Class W177 (AMG Line, MBUX) - ₺1.700.000-₺2.200.000 tavan
      'GJE': 3000000.0,       // CLA C118 (AMG Line, 4 Kapı Coupe) - ₺2.400.000-₺3.000.000 tavan
      '8 Serisi': 25000000.0, // G-Class (G 63 AMG) - ₺15.000.000-₺25.000.000+ tavan - OYUNUN EN PAHALI ARACI!
    },
    'Hundar': {
      'A10': 1100000.0,        // i20 III (Style Plus, Elite) - ₺900.000-₺1.100.000 tavan
      'Tecent Red': 700000.0,  // Accent Blue (Mode Plus, Dizel Oto) - ₺550.000-₺700.000 tavan
      'Tecent White': 520000.0, // Accent Era (Team, Dizel Oto) - ₺400.000-₺520.000 tavan
      'A20': 1600000.0,        // i30 III (Elite, N-Line) - ₺1.250.000-₺1.600.000 tavan
      'Kascon': 2500000.0,     // Tucson NX4 (Elite Plus, Hibrit) - ₺1.800.000-₺2.500.000 tavan
    },
    'Koyoro': {
      'Airoko': 2000000.0,     // Corolla E210 (Passion, Flame X-Pack, Hibrit) - ₺1.550.000-₺2.000.000 tavan
      'Lotus': 950000.0,       // Auris (Premium, Elegant, Hibrit) - ₺750.000-₺950.000 tavan
      'Karma': 1300000.0,      // Yaris XP210 (Passion, Hibrit) - ₺1.000.000-₺1.300.000 tavan
    },
    'Audira': {
      'B3': 2400000.0,         // A3 8Y (S Line, Edition One) 2023-2025 sıfıra yakın - ₺1.800.000-₺2.400.000 tavan
      'B4': 3600000.0,         // A4 B9/B10 (S Line, Design, Quattro) 2023-2025 - ₺2.600.000-₺3.600.000 tavan
      'B6': 5200000.0,         // A6 C8 (S Line, Exclusive, Quattro 3.0 V6) 2023-2025 - ₺4.000.000-₺5.200.000 tavan
      'B5': 4000000.0,         // A5 B9 (S Line, Sportback, Quattro) 2023-2025 - ₺3.000.000-₺4.000.000 tavan
    },
    'Hanto': {
      'Vice': 1850000.0,       // Civic FL (Executive, RS, Turbo) - ₺1.500.000-₺1.850.000 tavan
      'VHL': 2700000.0,        // CR-V 6. nesil (Executive, Hibrit, AWD) - ₺2.000.000-₺2.700.000 tavan
      'Caz': 1450000.0,        // Jazz 4. nesil (Executive, Hibrit) - ₺1.200.000-₺1.450.000 tavan
    },
    // Diğer markalar eklenecek
  };
  
  // Model-spesifik teknik özellik kuralları
  final Map<String, Map<String, dynamic>> _modelSpecs = {
    // RENAUVA SLIM (Clio) - %37.82 spawn
    'Renauva_Slim': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback']}, // Clio V nesil (2010 sonrası) sadece 5 kapı
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Benzin+LPG']},
          {'years': [2010, 2020], 'types': ['Dizel']}, // 1.5 dCi (Eski nesillerde)
          {'years': [2020, 2025], 'types': ['Hybrid']}, // E-Tech Hibrit (Clio V)
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (5-6 ileri) + EDC/X-Tronic CVT
      'driveType': 'Önden', // FWD - Tek ve standart
      'engineSize': {'min': 0.9, 'max': 1.5}, // 0.9 TCe (eski), 1.0 SCe/TCe, 1.5 dCi
      'horsepower': {'min': 65, 'max': 140}, // 65-140 HP (140 HP: E-Tech Hibrit)
    },
    
    // RENAUVA MAGNA (Megane) - %34.43 spawn
    'Renauva_Magna': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          // Eski kasa (çeşitlilik fazla)
          {'years': [2010, 2015], 'types': ['Sedan', 'Hatchback', 'Coupe', 'Station Wagon']},
          // Yeni kasa (Megane IV - daha modern)
          {'years': [2016, 2025], 'types': ['Sedan', 'Hatchback', 'Station Wagon']},
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          // Eski jenerasyon
          {'years': [2010, 2015], 'types': ['Benzin', 'Benzin+LPG', 'Dizel']},
          // Yeni jenerasyon (1.3 TCe ve 1.5 dCi)
          {'years': [2016, 2025], 'types': ['Benzin', 'Dizel']},
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (6 ileri) + EDC Otomatik (Çift Kavrama)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.3, 'max': 1.6}, // 1.3 TCe, 1.5 dCi, 1.6
      'horsepower': {'min': 95, 'max': 140}, // 95-140 HP (130-140 HP: TCe üst versiyon)
    },
    
    // RENAUVA FLOW (Fluence) - %13.49 spawn
    'Renauva_Flow': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan']}, // Fluence sadece Sedan (4 Kapı)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Benzin+LPG', 'Dizel']}, // 1.5 dCi çok popüler
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (5-6 ileri) + EDC Otomatik
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.5, 'max': 1.6}, // 1.5 dCi (1461cc), 1.6 Benzin (1598cc)
      'horsepower': {'min': 90, 'max': 110}, // 90-110 HP (Konfor odaklı)
    },
    
    // RENAUVA SIGNA (Symbol) - %11.50 spawn
    'Renauva_Signa': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan']}, // Symbol sadece Sedan (4 Kapı)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Benzin+LPG', 'Dizel']}, // 1.5 dCi en yaygın
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (5 ileri) + Easy-R (Yarı Otomatik - problemli)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.2, 'max': 1.5}, // 1.2, 1.4, 1.5 dCi
      'horsepower': {'min': 65, 'max': 95}, // 65-95 HP (Ekonomik yapı)
    },
    
    // RENAUVA TALLION (Taliant) - %2.73 spawn
    'Renauva_Tallion': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2021, 2025], 'types': ['Sedan']}, // Taliant sadece Sedan (4 Kapı), 2021 sonrası
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2021, 2025], 'types': ['Benzin', 'Benzin+LPG']}, // DİZEL YOK! Sadece Benzin/LPG
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (5 ileri) + X-Tronic CVT (Modern, sorunsuz)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.0, 'max': 1.0}, // Sadece 1.0 SCe/TCe (1.0 litre)
      'horsepower': {'min': 65, 'max': 90}, // 65-90 HP (Ekonomik B segment)
    },
    
    // VOLKSTAR PASO (Passat) - %40 spawn
    'Volkstar_Paso': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Station Wagon']}, // Station Wagon (Variant) nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // TSI (Benzin) ve TDI (Dizel)
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (6-7 ileri) + DSG (Çift Kavrama - RİSKLİ!)
      'driveType': 'Önden', // FWD - Standart (4Motion nadir)
      'engineSize': {'min': 1.4, 'max': 2.0}, // 1.4/1.5 TSI, 1.6 TDI, 2.0 TDI
      'horsepower': {'min': 120, 'max': 240}, // 120-240 HP (Premium segment)
    },
    
    // VOLKSTAR TENIS (Golf) - %25 spawn
    'Volkstar_Tenis': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback']}, // 5 kapı standart
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // TSI ve TDI
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (6-7 ileri) + DSG (RİSKLİ!)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.0, 'max': 1.6}, // 1.0 TSI, 1.2 TSI, 1.4/1.5 TSI, 1.6 TDI
      'horsepower': {'min': 90, 'max': 150}, // 90-150 HP (GTI/R versiyonları hariç)
    },
    
    // VOLKSTAR COLO (Polo) - %22 spawn
    'Volkstar_Colo': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback']}, // 5 kapı standart
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // TSI ve TDI
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (5 ileri) + DSG (Küçük motor, daha düşük risk)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.0, 'max': 1.6}, // 1.0 TSI, 1.2 TSI, 1.4/1.6 TDI
      'horsepower': {'min': 75, 'max': 115}, // 75-115 HP (Premium küçük segment)
    },
    
    // VOLKSTAR JAGO (Jetta) - %13 spawn
    'Volkstar_Jago': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan']}, // Sadece Sedan (4 kapı)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // TSI ve TDI
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (6-7 ileri) + DSG (ESKİ NESIL - YÜKSEK RİSK!)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.2, 'max': 1.6}, // 1.2 TSI, 1.4 TSI, 1.6 TDI
      'horsepower': {'min': 105, 'max': 150}, // 105-150 HP
    },
    
    // FIALTO AGNA (Egea) - %71.45 spawn (HACIM KRALI!)
    'Fialto_Agna': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2015, 2025], 'types': ['Sedan', 'Hatchback', 'Cross', 'Station Wagon']}, // Çok çeşitli
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2015, 2025], 'types': ['Benzin', 'Dizel']}, // Fire, T-Jet, Multijet
          {'years': [2020, 2025], 'types': ['Hybrid']}, // Yeni nesil hibrit
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (5-6 ileri) + DCT/Tork Konvertörlü
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.0, 'max': 1.6}, // 1.0 T-Jet, 1.3 Multijet, 1.4 Fire, 1.6 Multijet
      'horsepower': {'min': 95, 'max': 130}, // 95-130 HP
    },
    
    // FIALTO LAGUA (Linea) - %22.80 spawn
    'Fialto_Lagua': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan']}, // Sadece Sedan (üretim 2016'da durdu)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // Fire, Multijet
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (5 ileri) + Dualogic (YARI OTOMATİK - RİSKLİ!)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.3, 'max': 1.6}, // 1.3 Multijet, 1.4 Fire, 1.6 Multijet
      'horsepower': {'min': 77, 'max': 105}, // 77-105 HP (Ekonomik yapı)
    },
    
    // FIALTO ZORNO (Punto) - %5.72 spawn
    'Fialto_Zorno': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback']}, // 3 ve 5 kapı (üretim durdu)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // Fire, Multijet
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (5 ileri) + Dualogic (YARI OTOMATİK - RİSKLİ!)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.2, 'max': 1.4}, // 1.2/1.4 Fire, 1.3 Multijet
      'horsepower': {'min': 77, 'max': 95}, // 77-95 HP (En küçük segment)
    },
    
    // OPLON TASRA (Astra) - %55 spawn
    'Oplon_Tasra': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2018], 'types': ['Hatchback', 'Sedan']}, // Astra J - Sedan yaygın
          {'years': [2019, 2025], 'types': ['Hatchback']}, // Astra K/L - Modern hatchback
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // ECOTEC, CDTI
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (6 ileri) + Tork Konvertörlü (GÜVENİLİR!)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.2, 'max': 1.6}, // 1.2 Turbo, 1.4 Turbo, 1.5 Dizel, 1.6 CDTI/Benzin
      'horsepower': {'min': 110, 'max': 160}, // 110-160 HP
    },
    
    // OPLON LORISA (Corsa) - %32.3 spawn
    'Oplon_Lorisa': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2019], 'types': ['Hatchback']}, // Corsa D/E - 3 ve 5 kapı
          {'years': [2020, 2025], 'types': ['Hatchback']}, // Corsa F - Modern 5 kapı
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // ECOTEC, CDTI
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (5-6 ileri) + Easytronic (ESKİ - RİSKLİ!) / Tork (YENİ - GÜVENİLİR)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.2, 'max': 1.5}, // 1.2 Turbo, 1.4, 1.3/1.5 CDTI
      'horsepower': {'min': 75, 'max': 130}, // 75-130 HP
    },
    
    // OPLON MORNITIA (Insignia) - %12.7 spawn
    'Oplon_Mornitia': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Station Wagon']}, // Grand Sport / Sports Tourer nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // ECOTEC/SIDI, CDTI
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Manuel (6 ileri) + Tork Konvertörlü (GÜVENİLİR - PASSAT ALTERNATİFİ!)
      'driveType': 'Önden', // FWD - Standart (nadir 4x4)
      'engineSize': {'min': 1.5, 'max': 2.0}, // 1.5 Turbo, 1.6 Turbo/Dizel, 2.0 Dizel/Benzin
      'horsepower': {'min': 136, 'max': 220}, // 136-220 HP (Premium segment)
    },
    
    // BAVORA C SERİSİ (3 Serisi) - %40 spawn
    'Bavora_C Serisi': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Station Wagon']}, // Touring (SW) nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // i (Benzin), d (Dizel)
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 8 İleri Steptronic (ZF - ÇOK GÜVENİLİR!)
      'driveType': 'Arkadan', // RWD - Standart (xDrive opsiyonel)
      'engineSize': {'min': 1.6, 'max': 2.0}, // 1.6/2.0 Benzin, 1.6/2.0 Dizel
      'horsepower': {'min': 136, 'max': 258}, // 136-258 HP (Premium performans)
    },
    
    // BAVORA E SERİSİ (5 Serisi) - %25 spawn
    'Bavora_E Serisi': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Station Wagon']}, // Touring nadir lüks
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel', 'Hybrid']}, // i, d, e (Hibrit)
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 8 İleri Steptronic (ZF - ÇOK GÜVENİLİR!)
      'driveType': 'Arkadan', // RWD - Standart (xDrive opsiyonel)
      'engineSize': {'min': 2.0, 'max': 3.0}, // 2.0 (en yaygın), 3.0 (performans)
      'horsepower': {'min': 170, 'max': 340}, // 170-340 HP (En güçlü segment)
    },
    
    // BAVORA A SERİSİ (1 Serisi) - %22 spawn
    'Bavora_A Serisi': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2019], 'types': ['Hatchback']}, // F20 - 3 ve 5 kapı
          {'years': [2020, 2025], 'types': ['Hatchback']}, // F40 - 5 kapı
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // i, d
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 8 İleri (ESKİ - GÜVENİLİR) / 7 İleri DCT (YENİ - RİSK!)
      'driveType': 'Arkadan', // F20: RWD (eski), F40: FWD (yeni) - ÇEKİŞ FARKI KRİTİK!
      'engineSize': {'min': 1.5, 'max': 1.6}, // 1.5 (3 silindir), 1.6
      'horsepower': {'min': 116, 'max': 190}, // 116-190 HP
    },
    
    // BAVORA D SERİSİ (4 Serisi) - %13 spawn
    'Bavora_D Serisi': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Coupe', 'Sedan', 'Convertible']}, // Gran Coupe (Sedan), Cabrio
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // i (Benzin en yaygın), d (Dizel)
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 8 İleri Steptronic (ZF - ÇOK GÜVENİLİR!)
      'driveType': 'Arkadan', // RWD - Standart (xDrive opsiyonel)
      'engineSize': {'min': 2.0, 'max': 2.0}, // 2.0 Benzin/Dizel (vergi avantajı)
      'horsepower': {'min': 184, 'max': 258}, // 184-258 HP (Sportif segment)
    },
    
    // FORTRAN ODAK (Focus) - %59.08 spawn
    'Fortran_Odak': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback', 'Sedan', 'Station Wagon']}, // SW nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // EcoBoost, EcoBlue/TDCi
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Powershift (ESKİ - RİSKLİ!) / 8 İleri Tork (YENİ - GÜVENİLİR)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.0, 'max': 1.6}, // 1.0 EcoBoost, 1.5 EcoBoost/EcoBlue, 1.6 TDCi
      'horsepower': {'min': 100, 'max': 182}, // 100-182 HP
    },
    
    // FORTRAN VISTA (Fiesta) - %21.69 spawn
    'Fortran_Vista': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback']}, // 3 ve 5 kapı
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // EcoBoost, TDCi
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Powershift (ESKİ - RİSKLİ!) / Tam Otomatik/7 İleri DCT (YENİ)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.0, 'max': 1.5}, // 1.0 EcoBoost, 1.4/1.5 Benzin, 1.4/1.5 Dizel
      'horsepower': {'min': 75, 'max': 140}, // 75-140 HP
    },
    
    // FORTRAN AVGER (Ranger) - %10.32 spawn
    'Fortran_Avger': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Pick-up']}, // Çift Kabin yaygın, Tek Kabin nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Dizel']}, // EcoBlue/TDCi (Benzinli Raptor nadir)
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 6 İleri Manuel/Oto, 10 İleri Oto (YENİ - GÜVENİLİR)
      'driveType': '4x4', // 4x4 en yaygın ve değerli, 4x2 daha ucuz
      'engineSize': {'min': 2.0, 'max': 3.2}, // 2.0 Bi-Turbo (yeni), 2.2/3.2 TDCi (eski)
      'horsepower': {'min': 160, 'max': 213}, // 160-213 HP (Raptor daha yüksek)
    },
    
    // FORTRAN TUPA (Kuga) - %8.91 spawn
    'Fortran_Tupa': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['SUV']}, // 5 kapılı SUV
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel', 'Hybrid']}, // EcoBoost, EcoBlue/TDCi, Hibrit
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Powershift (ESKİ - RİSKLİ!) / 8 İleri Tork (YENİ - GÜVENİLİR)
      'driveType': 'Önden', // FWD yaygın, AWD (4x4) nadir premium
      'engineSize': {'min': 1.5, 'max': 2.5}, // 1.5 EcoBoost/EcoBlue, 2.0 EcoBlue, 2.5 Hibrit
      'horsepower': {'min': 120, 'max': 190}, // 120-190 HP
    },
    
    // MERCURION 3 SERİSİ (C-Class) - %42.18 spawn
    'Mercurion_3 Serisi': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Coupe', 'Convertible', 'Station Wagon']}, // Coupe/Cabrio nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel', 'Hybrid']}, // i, d, e
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 7G/9G-Tronic (ÇOK GÜVENİLİR!)
      'driveType': 'Arkadan', // RWD - Standart (4MATIC opsiyonel)
      'engineSize': {'min': 1.5, 'max': 2.0}, // 1.5/1.6/2.0 Benzin/Dizel
      'horsepower': {'min': 156, 'max': 258}, // 156-258 HP
    },
    
    // MERCURION 5 SERİSİ (E-Class) - %28.40 spawn
    'Mercurion_5 Serisi': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Coupe', 'Convertible', 'Station Wagon']}, // Coupe/Cabrio çok nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel', 'Hybrid']}, // i, d, e
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 7G/9G-Tronic (ÇOK GÜVENİLİR!)
      'driveType': 'Arkadan', // RWD - Standart (4MATIC opsiyonel)
      'engineSize': {'min': 1.6, 'max': 2.0}, // 1.6 Dizel (eski), 2.0 yaygın
      'horsepower': {'min': 170, 'max': 367}, // 170-367 HP (Oyunun en güçlü sedanlarından)
    },
    
    // MERCURION 1 SERİSİ (A-Class) - %10.19 spawn
    'Mercurion_1 Serisi': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback', 'Sedan']}, // A Sedan (CLA benzeri)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel', 'Hybrid']}, // i, d, EQ Boost
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 7G-DCT (ÇİFT KAVRAMA - DSG RİSKİ!)
      'driveType': 'Önden', // FWD - Standart (4MATIC opsiyonel)
      'engineSize': {'min': 1.33, 'max': 2.0}, // 1.33 turbo, 1.5/2.0 Dizel
      'horsepower': {'min': 116, 'max': 163}, // 116-163 HP
    },
    
    // MERCURION GJE (CLA) - %9.98 spawn
    'Mercurion_GJE': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Station Wagon']}, // 4 Kapı Coupe, Shooting Brake nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // i, d
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 7G/8G-DCT (ÇİFT KAVRAMA - DSG RİSKİ!)
      'driveType': 'Önden', // FWD - Standart (4MATIC opsiyonel)
      'engineSize': {'min': 1.33, 'max': 2.0}, // 1.33 turbo, 2.0 Dizel
      'horsepower': {'min': 136, 'max': 224}, // 136-224 HP (Daha güçlü)
    },
    
    // MERCURION 8 SERİSİ (G-Class) - %9.26 spawn
    'Mercurion_8 Serisi': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['SUV', 'Convertible']}, // Cabrio çok nadir bonus
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // i, d (AMG benzin)
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // 7G/9G-Tronic (ÇOK GÜVENİLİR!)
      'driveType': '4x4', // 4MATIC - Standart (3 diferansiyel kilidi)
      'engineSize': {'min': 3.0, 'max': 4.0}, // 3.0 Dizel, 4.0 V8 (AMG)
      'horsepower': {'min': 245, 'max': 585}, // 245-585 HP (OYUNUN EN GÜÇLÜ ARACI!)
    },
    
    // HUNDAR A10 (i20) - %52.15 spawn
    'Hundar_A10': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback']}, // 5 kapı
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel', 'Benzin+LPG']}, // MPi/T-GDI, CRDi
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Tork Konvertörlü (GÜVENİLİR!) / DCT (YENİ - ORTA RİSK)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.0, 'max': 1.4}, // 1.0 T-GDI, 1.4 MPi
      'horsepower': {'min': 75, 'max': 120}, // 75-120 HP
    },
    
    // HUNDAR TECENT RED (Accent Blue) - %19.25 spawn
    'Hundar_Tecent Red': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2018], 'types': ['Sedan']}, // 4 kapı (üretim durdu)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2018], 'types': ['Benzin', 'Dizel', 'Benzin+LPG']}, // CVVT, CRDi
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Tork Konvertörlü (ÇOK GÜVENİLİR!)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.4, 'max': 1.6}, // 1.4 CVVT, 1.6 CRDi
      'horsepower': {'min': 109, 'max': 136}, // 109-136 HP
    },
    
    // HUNDAR TECENT WHITE (Accent Era) - %10.95 spawn
    'Hundar_Tecent White': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2012], 'types': ['Sedan']}, // 4 kapı (üretim durdu - eski)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2012], 'types': ['Benzin', 'Dizel', 'Benzin+LPG']}, // CVVT, CRDi
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Tork Konvertörlü (GÜVENİLİR - ESKİ)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.4, 'max': 1.6}, // 1.4/1.6 CVVT, 1.5 CRDi
      'horsepower': {'min': 97, 'max': 110}, // 97-110 HP
    },
    
    // HUNDAR A20 (i30) - %9.95 spawn
    'Hundar_A20': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback', 'Station Wagon']}, // SW nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // T-GDI, CRDi
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Tork Konvertörlü (ESKİ) / DCT (YENİ - ORTA RİSK)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.4, 'max': 1.6}, // 1.4 T-GDI, 1.6 CRDi
      'horsepower': {'min': 120, 'max': 140}, // 120-140 HP
    },
    
    // HUNDAR KASCON (Tucson) - %7.69 spawn
    'Hundar_Kascon': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['SUV']}, // 5 kapı SUV
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel', 'Hybrid']}, // T-GDI, CRDi, HEV/PHEV
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // Tork Konvertörlü (ESKİ) / DCT (YENİ - ORTA RİSK)
      'driveType': 'Önden', // FWD yaygın, 4x4 nadir premium
      'engineSize': {'min': 1.6, 'max': 2.0}, // 1.6 T-GDI/CRDi, 2.0
      'horsepower': {'min': 136, 'max': 230}, // 136-230 HP (Hibrit en yüksek)
    },
    
    // KOYORO AIROKO (Corolla) - %81.93 spawn
    'Koyoro_Airoko': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Hatchback']}, // Sedan en yaygın, HB nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Hybrid', 'Benzin+LPG']}, // VVT-i, Hibrit
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // CVT (ÇOK GÜVENİLİR!) - Hiç MMT YOK
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.6, 'max': 1.8}, // 1.6 VVT-i, 1.8 Hibrit
      'horsepower': {'min': 124, 'max': 140}, // 124-140 HP
    },
    
    // KOYORO LOTUS (Auris) - %11.65 spawn
    'Koyoro_Lotus': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2018], 'types': ['Hatchback']}, // 5 kapı (üretim durdu)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2018], 'types': ['Benzin', 'Dizel', 'Hybrid', 'Benzin+LPG']}, // VVT-i, D-4D, Hibrit
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // CVT (GÜVENİLİR) + MMT (YARI OTOMATİK - RİSKLİ!)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.4, 'max': 1.8}, // 1.4 D-4D, 1.6 VVT-i, 1.8 Hibrit
      'horsepower': {'min': 90, 'max': 136}, // 90-136 HP
    },
    
    // KOYORO KARMA (Yaris) - %6.43 spawn
    'Koyoro_Karma': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback']}, // 5 kapı (eski nesil 3 kapı nadir)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Hybrid']}, // VVT-i, Hibrit
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // CVT (GÜVENİLİR) + MMT (ESKİ - YARI OTOMATİK - RİSKLİ!)
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.0, 'max': 1.5}, // 1.0, 1.33, 1.5 Hibrit
      'horsepower': {'min': 69, 'max': 116}, // 69-116 HP
    },
    
    // AUDIRA B3 (A3) - %45.05 spawn
    'Audira_B3': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Hatchback']}, // Sedan Türkiye'de popüler, Sportback (HB)
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // TFSI, TDI
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // S tronic (DSG RİSKİ!) - Manuel nadir
      'driveType': 'Önden', // FWD standart, Quattro güçlü motorlarda
      'engineSize': {'min': 1.0, 'max': 2.0}, // 1.0, 1.5 TFSI, 1.6 TDI
      'horsepower': {'min': 110, 'max': 190}, // 110-190 HP
    },
    
    // AUDIRA B4 (A4) - %23.75 spawn
    'Audira_B4': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'SW']}, // Sedan yaygın, Avant (SW) nadir Quattro
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // TFSI, TDI
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // S tronic (DSG) + Multitronic (ESKİ CVT RİSKİ!) + Tiptronic (Quattro GÜVENİLİR!)
      'driveType': 'Önden', // FWD standart, Quattro güçlü paketlerde
      'engineSize': {'min': 1.4, 'max': 2.0}, // 1.4, 2.0 TFSI/TDI
      'horsepower': {'min': 150, 'max': 252}, // 150-252 HP
    },
    
    // AUDIRA B6 (A6) - %20.87 spawn
    'Audira_B6': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'SW']}, // Sedan prestijli, Avant (SW) nadir güçlü
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Dizel', 'Benzin']}, // TDI yaygın, TFSI yeni
        ],
      },
      'transmissions': ['Otomatik'], // S tronic (DSG RİSK) + Tiptronic (Quattro GÜVENİLİR!)
      'driveType': 'Önden', // FWD, Quattro güçlü motorlarda
      'engineSize': {'min': 2.0, 'max': 3.0}, // 2.0 yaygın, 3.0 V6 prestijli
      'horsepower': {'min': 190, 'max': 340}, // 190-340 HP
    },
    
    // AUDIRA B5 (A5) - %10.33 spawn
    'Audira_B5': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Coupe', 'Hatchback']}, // Sportback (4 kapı) yaygın, Coupe (2 kapı) nadir, Cabriolet çok nadir
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Dizel']}, // TFSI, TDI
        ],
      },
      'transmissions': ['Otomatik'], // S tronic (DSG RİSK!) - Manuel çok nadir
      'driveType': 'Önden', // FWD standart, Quattro güçlü motorlarda
      'engineSize': {'min': 2.0, 'max': 2.0}, // 2.0 TFSI/TDI
      'horsepower': {'min': 190, 'max': 252}, // 190-252 HP
    },
    
    // HANTO VICE (Civic) - %80.46 spawn
    'Hanto_Vice': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Sedan', 'Hatchback']}, // Sedan en yaygın, HB 10. nesilde popüler
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Benzin+LPG']}, // VTEC, ECO (fabrika LPG)
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // CVT (ÇOK GÜVENİLİR!) + eski tork konv.
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.5, 'max': 1.6}, // 1.6 VTEC, 1.5 VTEC Turbo
      'horsepower': {'min': 125, 'max': 182}, // 125-182 HP (RS Turbo tavan)
    },
    
    // HANTO VHL (CR-V) - %10.34 spawn
    'Hanto_VHL': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['SUV']}, // 5 kapı SUV
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Hybrid']}, // VTEC Turbo, Hibrit
        ],
      },
      'transmissions': ['Otomatik'], // CVT (ÇOK GÜVENİLİR!) - Manuel nadir
      'driveType': 'Önden', // FWD yaygın, AWD (4x4) eski/güçlü motorlarda
      'engineSize': {'min': 1.5, 'max': 2.0}, // 1.5 Turbo, 2.0 atmosferik/Hibrit
      'horsepower': {'min': 155, 'max': 193}, // 155-193 HP
    },
    

    
    // HANTO CAZ (Jazz) - %3.45 spawn
    'Hanto_Caz': {
      'bodyTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Hatchback']}, // 5 kapı - tek kasa
        ],
      },
      'fuelTypes': {
        'rule': 'year_based',
        'ranges': [
          {'years': [2010, 2025], 'types': ['Benzin', 'Hybrid', 'Benzin+LPG']}, // VTEC, Hibrit (yeni)
        ],
      },
      'transmissions': ['Manuel', 'Otomatik'], // CVT (ÇOK GÜVENİLİR!) - Eski manuel de var
      'driveType': 'Önden', // FWD - Standart
      'engineSize': {'min': 1.3, 'max': 1.5}, // 1.3, 1.5 Hibrit
      'horsepower': {'min': 90, 'max': 122}, // 90-122 HP (Hibrit tavan)
    },
  };

  /// Servisi başlat
  Future<void> initialize() async {

    
    // İlk pazar oluştur
    await _generateInitialMarket();
    
    // Gün değişim listener'ı ekle
    _gameTime.addDayChangeListener(_onDayChange);
    

  }

  /// Gün değişiminde çağrılır
  void _onDayChange(int oldDay, int newDay) {

    _refreshMarket();
  }

  /// İlk pazarı oluştur (700-1200 ilan)
  Future<void> _generateInitialMarket() async {
    final totalListings = 700 + _random.nextInt(501); // 700-1200

    
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
    

  }

  /// Pazarı yenile (günlük)
  void _refreshMarket() {
    final currentDay = _gameTime.getCurrentDay();
    
    // 1) Süresi dolan ilanları bul ve kaldır
    final expiredListings = _activeListings.where((listing) {
      return listing.expiryDay <= currentDay;
    }).toList();
    
    if (expiredListings.isNotEmpty) {

      _activeListings.removeWhere((listing) => expiredListings.contains(listing));
    }
    
    // 2) Pazar çalkantısını kontrol et ve uygula
    _updateMarketShake();
    
    // 3) Yeni ilanlar oluştur (kaybolan ilan sayısı kadar)
    final newListingsNeeded = expiredListings.length;
    if (newListingsNeeded > 0) {

      _generateNewListings(newListingsNeeded);
    }
    

  }

  /// Pazar çalkantısını güncelle
  void _updateMarketShake() {
    // Aktif çalkantı varsa sayacı azalt
    if (_isMarketShakeActive) {
      _marketShakeDaysRemaining--;
      if (_marketShakeDaysRemaining <= 0) {

        _isMarketShakeActive = false;
        _marketShakeAdjustments.clear();
      }
    }
    
    // Yeni çalkantı başlatma kontrolü (%10 ihtimal)
    if (!_isMarketShakeActive && _random.nextDouble() < 0.10) {

      _isMarketShakeActive = true;
      _marketShakeDaysRemaining = 1 + _random.nextInt(2); // 1-2 gün
      
      // Her marka için -5% ile +5% arası ayarlama
      for (var brand in _brandSpawnRates.keys) {
        final adjustment = (_random.nextDouble() * 0.10) - 0.05; // -5% to +5%
        _marketShakeAdjustments[brand] = adjustment;
      }
      

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
    
    // Gerçekçi yıl dağılımı (marka-bazlı)
    final year = _generateRealisticYear(brand: brand, model: model);
    
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
    
    // Gerçek parça durumlarını oluştur
    final realPartConditions = _generatePartConditions();
    
    // YALAN SÖYLEME MANTIĞI (Ekspertiz Sistemi)
    // Varsayılan: Dürüst satıcı (Beyan = Gerçek)
    bool declaredAccidentRecord = hasAccidentRecord;
    int declaredMileage = mileage;
    Map<String, String> declaredPartConditions = Map.from(realPartConditions);
    
    // %25 ihtimalle satıcı yalan söyler (eğer saklanacak bir şey varsa)
    bool isLying = false;
    if (_random.nextDouble() < 0.25) {
      // 1. Hasar Kaydı Yalanı
      if (hasAccidentRecord) {
        declaredAccidentRecord = false; // "Hasar kaydı yok" yalanı
        isLying = true;
      }
      
      // 2. Kilometre Düşürme Yalanı (Yüksek km araçlarda)
      if (mileage > 180000) {
        // Km'yi %30-50 düşür
        declaredMileage = (mileage * (0.5 + _random.nextDouble() * 0.2)).toInt();
        isLying = true;
      }
      
      // 3. Parça Durumu Yalanı (Boyalı/Değişen parçaları temiz gösterme)
      final parts = realPartConditions.keys.toList();
      for (var part in parts) {
        if (realPartConditions[part] != 'orijinal') {
          // %70 ihtimalle bu parçayı temiz göster
          if (_random.nextDouble() < 0.70) {
            declaredPartConditions[part] = 'orijinal';
            isLying = true;
          }
        }
      }
    }
    
    // Fiyatı BEYAN EDİLEN özelliklere göre hesapla (Böylece ayıplı araç pahalıya satılır)
    final price = generateRealisticPrice(
      brand: brand,
      model: model,
      year: year,
      mileage: declaredMileage, // Beyan edilen km
      fuelType: fuelType,
      transmission: transmission,
      hasAccidentRecord: declaredAccidentRecord, // Beyan edilen hasar durumu
      sellerType: sellerType,
      driveType: driveType,
      bodyType: bodyType,
      horsepower: horsepower,
    );
    
    // Araç resmini belirle (Ölçeklenebilir yapı)
    String? imageUrl = _getVehicleImage(brand, model);
    
    // Renk belirle (Fialto Zorno için özel durum)
    String finalColor = _colors[_random.nextInt(_colors.length)];
    if (brand == 'Fialto' && model == 'Zorno') {
      finalColor = 'Standart';
    }

    // Araç objesi oluştur
    final vehicle = Vehicle.create(
      brand: brand,
      model: model,
      year: year,
      mileage: mileage, // Gerçek km
      price: price,
      location: _cities[_random.nextInt(_cities.length)],
      color: finalColor,
      fuelType: fuelType,
      transmission: transmission,
      imageUrl: imageUrl,
      condition: 'İkinci El',
      engineSize: engineSize,
      driveType: driveType,
      hasWarranty: _random.nextBool(),
      hasAccidentRecord: hasAccidentRecord, // Gerçek hasar durumu
      description: _generateDescription(
        brand: brand,
        model: model,
        fuelType: fuelType,
        transmission: transmission,
        year: year,
        driveType: driveType,
        horsepower: horsepower,
      ),
      bodyType: bodyType,
      horsepower: horsepower,
      sellerType: sellerType,
      partConditions: realPartConditions, // Gerçek parçalar
      
      // Ekspertiz verileri
      declaredAccidentRecord: declaredAccidentRecord,
      declaredMileage: declaredMileage,
      declaredPartConditions: declaredPartConditions,
      isExpertiseDone: false,
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

  /// Gerçekçi yıl oluştur (ağırlıklı, marka-bazlı)
  int _generateRealisticYear({String? brand, String? model}) {
    final rand = _random.nextDouble();
    final currentYear = DateTime.now().year;
    
    // Premium markalar ve pick-up'lar için daha eski araçlar (fiyat gerçekçiliği)
    final isPremium = brand == 'Volkstar' || brand == 'Bavora' || brand == 'Mercurion' || brand == 'Audira' || brand == 'Oplon';
    final isUltraLux = brand == 'Mercurion' && model == '8 Serisi'; // G-Class ultra lüks
    final isPickupOrSUV = (brand == 'Fortran' && (model == 'Avger' || model == 'Tupa'));
    
    if (isPremium || isPickupOrSUV) {
      // Premium markalar: Daha eski araçlar ağırlıklı (fiyat gerçekçiliği için)
      if (rand < 0.15) {
        // %15: Son 3 yıl (2022-2024)
      return currentYear - _random.nextInt(3);
      } else if (rand < 0.50) {
        // %35: 4-7 yaşında (2018-2021)
      return currentYear - (4 + _random.nextInt(4));
    } else {
        // %50: 8-15 yaşında (2010-2017) - EN YAYGIN
        return currentYear - (8 + _random.nextInt(8));
      }
    } else {
      // Normal markalar: Daha dengeli dağılım
      if (rand < 0.30) {
        // %30: Son 3 yıl (2022-2024)
        return currentYear - _random.nextInt(3);
      } else if (rand < 0.65) {
        // %35: 4-7 yaşında (2018-2021)
        return currentYear - (4 + _random.nextInt(4));
      } else {
        // %35: 8+ yaşında (2010-2017)
        return currentYear - (8 + _random.nextInt(8));
      }
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

  /// Gerçekçi fiyat oluştur (Marka, model, yıl ve km bazlı)
  double generateRealisticPrice({
    required String brand,
    required String model,
    required int year,
    required int mileage,
    required String fuelType,
    required String transmission,
    required bool hasAccidentRecord,
    required String sellerType,
    required String driveType,
    required String bodyType,
    required int horsepower,
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
    
    // MODEL-SPESİFİK DEĞER KAYBI ORANI

    if (brand == 'Renauva') {
      if (model == 'Flow') {
        // Fluence: Üretimi durmuş, daha hızlı değer kaybediyor
        yearFactor *= 0.92; // Ekstra %8 değer kaybı
      } else if (model == 'Tallion') {
        // Taliant: Yeni nesil, değer koruması daha iyi
        yearFactor *= 1.05; // %5 daha iyi değer koruması
      } else if (model == 'Signa') {
        // Symbol: Ekonomik segment, orta düzey değer kaybı
        yearFactor *= 0.95; // %5 değer kaybı
      }
    } else if (brand == 'Volkstar') {
      if (model == 'Jago') {
        // Jetta: Üretimi durmuş (2018), değer kaybı hızlı
        yearFactor *= 0.90; // Ekstra %10 değer kaybı
      } else if (model == 'Paso') {
        // Passat: Premium segment, değer koruması iyi
        yearFactor *= 1.03; // %3 daha iyi değer koruması
      } else if (model == 'Tenis') {
        // Golf: Yüksek talep, değer koruması çok iyi
        yearFactor *= 1.05; // %5 daha iyi değer koruması
      }
    } else if (brand == 'Fialto') {
      if (model == 'Lagua' || model == 'Zorno') {
        // Linea ve Punto: Üretimi durmuş, değer kaybı hızlı
        yearFactor *= 0.88; // Ekstra %12 değer kaybı (stokta tutma riski)
      } else if (model == 'Agna') {
        // Egea: Yüksek hacim, rekabet nedeniyle orta değer koruması
        yearFactor *= 0.97; // %3 değer kaybı
      }
    } else if (brand == 'Oplon') {
      if (model == 'Mornitia') {
        // Insignia: Premium segment, iyi değer koruması
        yearFactor *= 1.02; // %2 daha iyi değer koruması
      } else if (model == 'Tasra') {
        // Astra: Orta segment, dengeli değer koruması
        yearFactor *= 1.00; // Standart
      } else if (model == 'Lorisa') {
        // Corsa: Küçük segment, orta değer koruması
        yearFactor *= 0.98; // %2 değer kaybı
      }
    } else if (brand == 'Bavora') {
      // Premium marka - genel olarak iyi değer koruması
      if (model == 'E Serisi') {
        // 5 Serisi: En prestijli, en iyi değer koruması
        yearFactor *= 1.08; // %8 daha iyi değer koruması
      } else if (model == 'C Serisi') {
        // 3 Serisi: Popüler, çok iyi değer koruması
        yearFactor *= 1.06; // %6 daha iyi değer koruması
      } else if (model == 'D Serisi') {
        // 4 Serisi: Sportif, iyi değer koruması
        yearFactor *= 1.05; // %5 daha iyi değer koruması
      } else if (model == 'A Serisi') {
        // 1 Serisi: Kompakt premium, iyi değer koruması
        yearFactor *= 1.04; // %4 daha iyi değer koruması
      }
    } else if (brand == 'Fortran') {
      if (model == 'Avger') {
        // Ranger: Pick-up, yüksek değer koruması
        yearFactor *= 1.07; // %7 daha iyi değer koruması (ticari araç talebi)
      } else if (model == 'Tupa') {
        // Kuga: SUV segment, iyi değer koruması
        yearFactor *= 1.03; // %3 daha iyi değer koruması
      } else if (model == 'Odak') {
        // Focus: Popüler C segment, dengeli
        yearFactor *= 1.00; // Standart
      } else if (model == 'Vista') {
        // Fiesta: B segment, orta değer koruması
        yearFactor *= 0.98; // %2 değer kaybı
      }
    } else if (brand == 'Mercurion') {
      // Ultra premium - en yüksek değer koruması
      if (model == '8 Serisi') {
        // G-Class: Efsanevi değer koruması
        yearFactor *= 1.12; // %12 daha iyi (yatırım aracı)
      } else if (model == '5 Serisi') {
        // E-Class: Premium lüks, yüksek değer koruması
        yearFactor *= 1.09; // %9 daha iyi
      } else if (model == '3 Serisi') {
        // C-Class: Popüler premium, çok iyi değer koruması
        yearFactor *= 1.07; // %7 daha iyi
      } else if (model == 'GJE') {
        // CLA: Sportif coupe, iyi değer koruması
        yearFactor *= 1.06; // %6 daha iyi
      } else if (model == '1 Serisi') {
        // A-Class: Kompakt premium, iyi değer koruması
        yearFactor *= 1.05; // %5 daha iyi
      }
    } else if (brand == 'Hundar') {
      if (model == 'Kascon') {
        // Tucson: SUV segment, iyi değer koruması
        yearFactor *= 1.04; // %4 daha iyi
      } else if (model == 'A20') {
        // i30: Orta segment, dengeli değer koruması
        yearFactor *= 1.02; // %2 daha iyi
      } else if (model == 'A10') {
        // i20: B segment, standart değer koruması
        yearFactor *= 1.00; // Standart
      } else if (model == 'Tecent Red') {
        // Accent Blue: Üretimi durmuş, orta değer kaybı
        yearFactor *= 0.95; // %5 değer kaybı
      } else if (model == 'Tecent White') {
        // Accent Era: Çok eski, hızlı değer kaybı
        yearFactor *= 0.88; // %12 değer kaybı (taksi/filo riski)
      }
    } else if (brand == 'Koyoro') {
      // Maksimum güvenilirlik ve değer koruması
      if (model == 'Airoko') {
        // Corolla: EN AZ değer kaybı - efsanevi güvenilirlik
        yearFactor *= 1.10; // %10 daha iyi (maksimum değer koruması)
      } else if (model == 'Lotus') {
        // Auris: Üretimi durmuş ama Toyota güvenilirliği
        yearFactor *= 1.03; // %3 daha iyi (markaya güven)
      } else if (model == 'Karma') {
        // Yaris: Kompakt premium, çok iyi değer koruması
        yearFactor *= 1.07; // %7 daha iyi
      }
    } else if (brand == 'Audira') {
      // Premium segment ama yüksek arıza riski nedeniyle daha hızlı değer kaybı
      if (model == 'B3') {
        // A3: Premium kompakt ama DSG riski
        yearFactor *= 0.95; // %5 değer kaybı (DSG riski)
      } else if (model == 'B4') {
        // A4: D segment ama çoklu şanzıman riski
        yearFactor *= 0.92; // %8 değer kaybı (S tronic/Multitronic riski)
      } else if (model == 'B6') {
        // A6: E segment + elektronik + şanzıman çift riski
        yearFactor *= 0.88; // %12 değer kaybı (çift risk: şanzıman + elektronik)
      } else if (model == 'B5') {
        // A5: Sportif premium ama DSG riski
        yearFactor *= 0.93; // %7 değer kaybı (DSG riski + niş segment)
      }
    } else if (brand == 'Hanto') {
      // İkinci el kralı - Corolla benzeri değer koruması
      if (model == 'Vice') {
        // Civic: EN AZ değer kaybeden sedanlardan - ikinci el kralı
        yearFactor *= 1.09; // %9 daha iyi (maksimum değer koruması)
      } else if (model == 'VHL') {
        // CR-V: SUV segmentinde en az değer kaybeden
        yearFactor *= 1.07; // %7 daha iyi
      } else if (model == 'Caz') {
        // Jazz: Sihirli koltuk - niş ama değerli
        yearFactor *= 1.06; // %6 daha iyi
      }
    }
    
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
    
    // Tecent White (Accent Era) taksi/filo geçmişi riski
    if (brand == 'Hundar' && model == 'Tecent White' && mileage > 200000) {
      kmFactor *= 0.90; // Yüksek km Accent Era taksi riski - ekstra %10 değer kaybı
    }
    
    // Audira A6 (B6) kilometre hassasiyeti - E segment uzun yol riski
    if (brand == 'Audira' && model == 'B6' && mileage > 150000) {
      kmFactor *= 0.87; // Yüksek km A6 - çok yüksek arıza riski (motor/şanzıman/elektronik)
    }
    
    // YAKIT TİPİ FAKTÖRÜ
    double fuelFactor = 1.0;
    if (fuelType == 'Dizel') {
      fuelFactor = 1.10; // Dizel %10 daha değerli
    } else if (fuelType == 'Hybrid') {
      fuelFactor = 1.15; // Hybrid %15 daha değerli
    } 
    // else if (fuelType == 'Elektrik') {
    //   fuelFactor = 1.20; // Elektrik %20 daha değerli
    // } 
    else if (fuelType == 'Benzin+LPG') {
      fuelFactor = 1.12; // LPG %12 daha değerli (yakıt tasarrufu)
    } else {
      fuelFactor = 1.0; // Benzin
    }
    
    // MODEL-SPESİFİK YAKIT DEĞERİ
    if (brand == 'Renauva') {
      if (model == 'Flow' && fuelType == 'Dizel') {
        // Fluence 1.5 dCi: Çok popüler kombinasyon
        fuelFactor *= 1.05; // Ekstra %5 değer
      } else if (model == 'Signa' && fuelType == 'Dizel') {
        // Symbol 1.5 dCi: En çok talep gören
        fuelFactor *= 1.08; // Ekstra %8 değer
      } else if (model == 'Tallion' && fuelType == 'Benzin+LPG') {
        // Taliant Fabrika LPG: Yüksek talep
        fuelFactor *= 1.10; // Ekstra %10 değer
      }
    } else if (brand == 'Volkstar') {
      if (fuelType == 'Dizel') {
        // TDI motorlar Volkstar'da çok popüler
        if (model == 'Paso' || model == 'Tenis') {
          fuelFactor *= 1.12; // Paso/Tenis TDI çok değerli
        } else if (model == 'Jago') {
          fuelFactor *= 1.15; // Jetta 1.6 TDI en popüler kombinasyon
        }
      }
    } else if (brand == 'Fialto') {
      if (fuelType == 'Dizel') {
        // Multijet Dizel motorlar Fialto'da çok popüler
        if (model == 'Agna') {
          fuelFactor *= 1.10; // Agna 1.3/1.6 Multijet çok talep görüyor
        } else if (model == 'Lagua' || model == 'Zorno') {
          fuelFactor *= 1.12; // Lagua/Zorno 1.3 Multijet en popüler
        }
      }
      
      // TİCARİ GEÇMŞ RİSKİ (Agna için)
      if (model == 'Agna' && mileage > 150000) {
        // Yüksek kilometreli Agna: Ticari filo / taksi riski
        fuelFactor *= 0.93; // %7 değer düşüşü (ağır kullanım riski)
      }
    } else if (brand == 'Oplon') {
      if (fuelType == 'Dizel') {
        // CDTI Dizel motorlar Oplon'da çok popüler ve verimli
        if (model == 'Tasra') {
          fuelFactor *= 1.12; // Tasra 1.6 CDTI çok talep görüyor
        } else if (model == 'Lorisa') {
          fuelFactor *= 1.10; // Lorisa Dizel düşük tüketim - yüksek talep
        } else if (model == 'Mornitia') {
          fuelFactor *= 1.14; // Mornitia 1.6/2.0 CDTI premium değer
        }
      }
    } else if (brand == 'Bavora') {
      if (fuelType == 'Dizel') {
        // d motorlar (Dizel) çok popüler ve verimli
        if (model == 'C Serisi') {
          fuelFactor *= 1.15; // 320d/318d en popüler kombinasyon
        } else if (model == 'E Serisi') {
          fuelFactor *= 1.18; // 520d/530d lüks segment en verimli
        } else if (model == 'A Serisi') {
          fuelFactor *= 1.12; // 116d/118d ekonomik premium
        } else if (model == 'D Serisi') {
          fuelFactor *= 1.14; // 420d sportif dizel
        }
      } else if (fuelType == 'Hybrid') {
        // Hibrit (e motorlar) - yüksek teknoloji
        if (model == 'E Serisi') {
          fuelFactor *= 1.25; // 530e hibrit en yüksek teknoloji primi
        }
      }
    } else if (brand == 'Fortran') {
      if (fuelType == 'Dizel') {
        // EcoBlue/TDCi Dizel motorlar çok popüler
        if (model == 'Odak') {
          fuelFactor *= 1.10; // Focus 1.5 EcoBlue/TDCi popüler
        } else if (model == 'Vista') {
          fuelFactor *= 1.08; // Fiesta Dizel ekonomik
        } else if (model == 'Avger') {
          fuelFactor *= 1.12; // Ranger Dizel en yaygın
        } else if (model == 'Tupa') {
          fuelFactor *= 1.11; // Kuga Dizel verimli
        }
      } else if (fuelType == 'Hybrid') {
        // Hibrit (Kuga) - yüksek teknoloji primi
        if (model == 'Tupa') {
          fuelFactor *= 1.22; // Kuga Hibrit yüksek teknoloji + vergi avantajı
        }
      }
    } else if (brand == 'Mercurion') {
      if (fuelType == 'Dizel') {
        // Dizel motorlar (d) çok popüler ve verimli
        if (model == '3 Serisi') {
          fuelFactor *= 1.16; // C200d/C220d çok talep görüyor
        } else if (model == '5 Serisi') {
          fuelFactor *= 1.19; // E220d/E200d lüks segment en verimli
        } else if (model == '1 Serisi') {
          fuelFactor *= 1.13; // A180d ekonomik premium
        } else if (model == 'GJE') {
          fuelFactor *= 1.15; // CLA 200d sportif dizel
        } else if (model == '8 Serisi') {
          fuelFactor *= 1.10; // G 350d verimli arazi (benzin daha popüler)
        }
      } else if (fuelType == 'Hybrid') {
        // Hibrit (e motorlar) - yüksek teknoloji primi
        if (model == '3 Serisi') {
          fuelFactor *= 1.24; // C200/C300 hibrit yüksek teknoloji
        } else if (model == '5 Serisi') {
          fuelFactor *= 1.27; // E300e hibrit en yüksek teknoloji primi
        }
      } else if (fuelType == 'Benzin') {
        // G-Class'ta benzin (özellikle AMG) çok değerli
        if (model == '8 Serisi') {
          fuelFactor *= 1.20; // G 500 / G 63 AMG benzin king
        }
      }
    } else if (brand == 'Koyoro') {
      if (fuelType == 'Hybrid') {
        // Hibrit teknolojisi - Toyota'nın ana gücü
        if (model == 'Airoko') {
          fuelFactor *= 1.28; // Corolla 1.8 Hibrit en popüler (+%28 değer!)
        } else if (model == 'Lotus') {
          fuelFactor *= 1.24; // Auris Hibrit yüksek talep (+%24 değer)
        } else if (model == 'Karma') {
          fuelFactor *= 1.25; // Yaris 1.5 Hibrit kompakt premium (+%25 değer)
        }
      } else if (fuelType == 'Dizel') {
        // Dizel (sadece Auris'te)
        if (model == 'Lotus') {
          fuelFactor *= 1.09; // Auris 1.4 D-4D verimli
        }
      } else if (fuelType == 'Benzin+LPG') {
        // LPG uyumu
        fuelFactor *= 0.97; // LPG dönüşüm -%3 değer
      }
    } else if (brand == 'Hanto') {
      if (fuelType == 'Hybrid') {
        // Hibrit teknolojisi - Honda'nın güçlü yönü
        if (model == 'VHL') {
          fuelFactor *= 1.26; // CR-V 2.0 Hibrit premium SUV (+%26 değer!)
        } else if (model == 'Caz') {
          fuelFactor *= 1.23; // Jazz 1.5 e:HEV hibrit kompakt (+%23 değer)
        }
      } else if (fuelType == 'Benzin+LPG') {
        // ECO (FABRİKA ÇIKIŞLI LPG) - Honda'nın özel avantajı
        if (model == 'Vice') {
          fuelFactor *= 1.11; // Civic ECO fabrika LPG - yüksek talep (+%11 değer)
        } else if (model == 'Caz') {
          fuelFactor *= 1.08; // Jazz LPG uyumu (+%8 değer)
        }
      }
    } else if (brand == 'Audira') {
      if (fuelType == 'Dizel') {
        // Dizel premium segmentte çok değerli
        if (model == 'B6') {
          fuelFactor *= 1.21; // A6 2.0/3.0 TDI çok talep görür (+%21 değer)
        } else if (model == 'B4') {
          fuelFactor *= 1.18; // A4 2.0 TDI popüler (+%18 değer)
        } else if (model == 'B5') {
          fuelFactor *= 1.16; // A5 40 TDI yakıt ekonomisi (+%16 değer)
        } else if (model == 'B3') {
          fuelFactor *= 1.14; // A3 TDI verimli (+%14 değer)
        }
      }
    } else if (brand == 'Hundar') {
      if (fuelType == 'Dizel') {
        // CRDi Dizel motorlar güçlü ve verimli
        if (model == 'Tecent Red') {
          fuelFactor *= 1.14; // Accent Blue 1.6 CRDi güçlü (+%14 değer)
        } else if (model == 'Tecent White') {
          fuelFactor *= 1.12; // Accent Era 1.5 CRDi ekonomik
        } else if (model == 'A20') {
          fuelFactor *= 1.13; // i30 1.6 CRDi popüler
        } else if (model == 'Kascon') {
          fuelFactor *= 1.15; // Tucson 1.6 CRDi SUV verimli
        }
      } else if (fuelType == 'Hybrid') {
        // Hibrit (Tucson) - yüksek teknoloji primi
        if (model == 'Kascon') {
          fuelFactor *= 1.26; // Tucson Hibrit en yüksek talep (+%26 değer!)
        }
      } else if (fuelType == 'Benzin+LPG') {
        // LPG ekonomik seçenek
        if (model == 'A10' || model == 'Tecent Red' || model == 'Tecent White') {
          fuelFactor *= 0.96; // LPG dönüşüm değer kaybı -%4
        }
      }
    }
    
    // VİTES FAKTÖRÜ (Model-spesifik vites tipleri)
    double transFactor = 1.0;
    if (transmission == 'Otomatik') {
      transFactor = 1.08; // Temel otomatik %8 daha değerli
      
      // MODEL-SPESİFİK VİTES DEĞERİ (Renauva için)
      if (brand == 'Renauva') {
        if (model == 'Signa') {
          // Symbol Easy-R: Düşük güvenilirlik, düşük değer
          transFactor = 0.95; // Manuel'den bile %5 düşük (risk faktörü)
        } else if (model == 'Tallion') {
          // Taliant X-Tronic CVT: Modern ve güvenilir
          transFactor = 1.12; // %12 daha değerli
        } else if (model == 'Slim' || model == 'Magna') {
          // Clio/Megane EDC/X-Tronic: Güvenilir otomatik
          transFactor = 1.10; // %10 daha değerli
        } else if (model == 'Flow') {
          // Fluence EDC: İyi ama bir nesil eski
          transFactor = 1.06; // %6 daha değerli (eski nesil riski)
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Volkstar için - DSG RİSKİ!)
      else if (brand == 'Volkstar') {
        // DSG (Çift Kavrama) - Yüksek talep AMA yüksek arıza riski
        final vehicleAge = 2025 - year;
        
        if (model == 'Jago') {
          // Jetta: ESKİ NESIL DSG - EN YÜKSEK RİSK!
          if (vehicleAge >= 8) {
            // 2017 ve öncesi - Çok riskli
            transFactor = 0.92; // Manuel'den bile düşük (arıza riski çok yüksek)
          } else if (vehicleAge >= 5) {
            transFactor = 1.02; // Minimal değer artışı (risk var)
          } else {
            transFactor = 1.08; // Nispeten güvenli
          }
        } else if (model == 'Paso') {
          // Passat: Büyük DSG - Orta-Yüksek risk
          if (vehicleAge >= 8 || mileage > 150000) {
            transFactor = 0.98; // Arıza riski nedeniyle düşük değer
          } else if (vehicleAge >= 5) {
            transFactor = 1.05; // Orta seviye bonus
          } else {
            transFactor = 1.14; // Yeni ve güvenli - yüksek talep
          }
        } else if (model == 'Tenis') {
          // Golf: En popüler DSG - Orta risk
          if (vehicleAge >= 8) {
            transFactor = 1.00; // Manuel ile eşit (risk dengesi)
          } else if (vehicleAge >= 5) {
            transFactor = 1.08; // İyi değer
          } else {
            transFactor = 1.15; // Yüksek talep ve değer
          }
        } else if (model == 'Colo') {
          // Polo: Küçük DSG - Düşük risk
          transFactor = 1.10; // Küçük motor, daha az yıpranma
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Fialto için - DUALOGIC RİSKİ!)
      else if (brand == 'Fialto') {
        if (model == 'Lagua' || model == 'Zorno') {
          // Dualogic (Yarı Otomatik) - Easy-R gibi düşük güvenilirlik!
          transFactor = 0.90; // Manuel'den %10 düşük (arıza riski + düşük talep)
        } else if (model == 'Agna') {
          // Agna: DCT/Tork Konvertörlü - Daha güvenilir
          transFactor = 1.06; // %6 daha değerli (DSG kadar prestijli değil)
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Oplon için - TORK KONVERTÖRLÜ GÜVENİLİRLİK!)
      else if (brand == 'Oplon') {
        final vehicleAge = 2025 - year;
        
        if (model == 'Lorisa') {
          // Corsa: Nesil farkı kritik!
          if (vehicleAge >= 6) {
            // 2019 öncesi (Corsa D/E) - Easytronic riski!
            transFactor = 0.93; // Easy-R gibi yarı otomatik - yüksek risk
          } else {
            // 2020+ (Corsa F) - Modern tork konvertörlü
            transFactor = 1.12; // Güvenilir ve prestijli
          }
        } else if (model == 'Tasra' || model == 'Mornitia') {
          // Astra/Insignia: Tork Konvertörlü - DSG'den daha güvenilir!
          // "Daha Az Riskli Otomatik" algısı
          if (vehicleAge >= 8 || mileage > 180000) {
            transFactor = 1.06; // Eski ama güvenilir - orta bonus
          } else if (vehicleAge >= 5) {
            transFactor = 1.10; // İyi değer - güvenilirlik bonusu
          } else {
            transFactor = 1.13; // DSG riskinden kaçan alıcılar - yüksek talep
          }
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Bavora için - ZF GÜVENİLİRLİĞİ!)
      else if (brand == 'Bavora') {
        final vehicleAge = 2025 - year;
        
        if (model == 'A Serisi') {
          // 1 Serisi: Nesil ve çekiş farkı KRİTİK!
          if (vehicleAge >= 6) {
            // 2019 öncesi (F20 - RWD + ZF 8 ileri) - Çok güvenilir!
            transFactor = 1.15; // RWD + ZF güvenilirliği - sportif premium
          } else {
            // 2020+ (F40 - FWD + 7 ileri DCT) - DSG benzeri risk!
            transFactor = 1.05; // DCT riski var ama yeni teknoloji
          }
        } else if (model == 'C Serisi' || model == 'E Serisi' || model == 'D Serisi') {
          // 3/4/5 Serisi: ZF 8 ileri Steptronic - ÇOK GÜVENİLİR!
          // DSG'den ve DCT'den çok daha güvenilir
          if (vehicleAge >= 10 || mileage > 200000) {
            transFactor = 1.08; // Eski ama ZF güvenilirliği - orta bonus
          } else if (vehicleAge >= 5) {
            transFactor = 1.12; // İyi değer - ZF güvenilirlik bonusu
          } else {
            transFactor = 1.16; // Yeni + ZF = en güvenilir otomatik kombinasyon
          }
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Fortran için - POWERSHIFT RİSKİ!)
      else if (brand == 'Fortran') {
        final vehicleAge = 2025 - year;
        
        if (model == 'Odak' || model == 'Vista' || model == 'Tupa') {
          // Focus/Fiesta/Kuga: Powershift riski KRİTİK!
          if (vehicleAge >= 9) {
            // 2016 öncesi - Powershift çift kavrama - YÜKSEK RİSK!
            transFactor = 0.88; // DSG gibi yüksek arıza riski - manuel'den %12 düşük
          } else if (vehicleAge >= 7) {
            // 2018 öncesi - Hala Powershift riski var
            transFactor = 0.92; // Orta risk - manuel'den %8 düşük
          } else {
            // 2018+ - Yeni 8 ileri tork konvertörlü - GÜVENİLİR!
            if (model == 'Odak') {
              transFactor = 1.10; // Focus yeni nesil güvenilir
            } else if (model == 'Vista') {
              transFactor = 1.08; // Fiesta yeni nesil güvenilir
            } else if (model == 'Tupa') {
              transFactor = 1.12; // Kuga SUV + güvenilir otomatik
            }
          }
        } else if (model == 'Avger') {
          // Ranger: 6 ileri veya 10 ileri otomatik - Powershift yok
          if (vehicleAge <= 3) {
            transFactor = 1.14; // 10 ileri otomatik - modern ve prestijli
          } else {
            transFactor = 1.08; // 6 ileri otomatik - güvenilir
          }
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Mercurion için - 7G/9G vs DCT)
      else if (brand == 'Mercurion') {
        final vehicleAge = 2025 - year;
        
        if (model == '1 Serisi' || model == 'GJE') {
          // A-Class/CLA: 7G-DCT çift kavrama - DSG benzeri risk!
          if (vehicleAge >= 7) {
            transFactor = 0.95; // Eski DCT - orta risk
          } else {
            transFactor = 1.07; // Yeni DCT - teknoloji primi ama risk var
          }
        } else if (model == '3 Serisi' || model == '5 Serisi' || model == '8 Serisi') {
          // C/E/G-Class: 7G/9G-Tronic - ÇOK GÜVENİLİR!
          // ZF seviyesinde güvenilirlik
          if (vehicleAge >= 10 || mileage > 200000) {
            transFactor = 1.10; // Eski ama 7G/9G güvenilirliği
          } else if (vehicleAge >= 5) {
            transFactor = 1.14; // İyi değer - Mercedes güvenilirlik bonusu
          } else {
            transFactor = 1.18; // Yeni + 9G = en güvenilir otomatik
          }
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Hundar için - TORK KONVERTÖRLÜ GÜVENİLİRLİK!)
      else if (brand == 'Hundar') {
        final vehicleAge = 2025 - year;
        
        if (model == 'Tecent White' || model == 'Tecent Red') {
          // Accent Era/Blue: Tork konvertörlü - Symbol/Lagua'dan GÜVENİLİR!
          // Easy-R/Dualogic riskine karşı avantaj
          transFactor = 1.11; // Tork konvertörlü güvenilirlik bonusu
        } else if (model == 'A10') {
          // i20: Eski tork konvertörlü, yeni DCT
          if (vehicleAge >= 5) {
            transFactor = 1.09; // Eski tork konvertörlü - güvenilir
          } else {
            transFactor = 1.04; // Yeni DCT - orta risk (Powershift'ten iyi, tork'tan az güvenilir)
          }
        } else if (model == 'A20') {
          // i30: Eski tork konvertörlü, yeni DCT
          if (vehicleAge >= 6) {
            transFactor = 1.10; // Eski tork konvertörlü - güvenilir
          } else {
            transFactor = 1.05; // Yeni DCT - orta risk
          }
        } else if (model == 'Kascon') {
          // Tucson: Eski tork konvertörlü, yeni DCT
          if (vehicleAge >= 6) {
            transFactor = 1.11; // Eski tork konvertörlü - SUV + güvenilir
          } else {
            transFactor = 1.07; // Yeni DCT - orta risk ama SUV primi
          }
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Koyoro için - CVT GÜVENİLİRLİĞİ!)
      else if (brand == 'Koyoro') {
        final vehicleAge = 2025 - year;
        
        if (model == 'Airoko') {
          // Corolla: Sadece CVT - HİÇ MMT YOK - EN GÜVENİLİR!
          // DSG/Powershift/DCT risklerinden TAM UZAK
          transFactor = 1.17; // CVT güvenilirlik + Toyota markası = MAKSIMUM BONUS
        } else if (model == 'Lotus') {
          // Auris: CVT (güvenilir) + MMT (riskli)
          // MMT sadece 1.4 D-4D Dizel'de kullanılır
          if (fuelType == 'Dizel' && vehicleAge >= 7) {
            // Eski 1.4 D-4D MMT - Easy-R/Dualogic gibi YARI OTOMATİK RİSK!
            transFactor = 0.89; // MMT yarı otomatik - yüksek arıza riski
          } else {
            // CVT (Hibrit/Benzin) - Çok güvenilir
            transFactor = 1.14; // CVT güvenilirlik bonusu
          }
        } else if (model == 'Karma') {
          // Yaris: CVT (güvenilir) + MMT (eski riskli)
          if (vehicleAge >= 10) {
            // Eski nesil (2010-2015) MMT riski var
            transFactor = 0.91; // MMT yarı otomatik riski (1.33 benzin)
          } else {
            // Yeni CVT (Hibrit/1.5 Benzin) - Çok güvenilir
            transFactor = 1.13; // CVT güvenilirlik bonusu
          }
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Audira için - S tronic/MULTITRONIC RİSKİ!)
      else if (brand == 'Audira') {
        final vehicleAge = 2025 - year;
        
        // Quattro kontrolü (driveType'dan)
        final bool hasQuattro = driveType == '4x4';
        
        if (model == 'B3') {
          // A3: S tronic (DSG) risk - Premium parça maliyeti!
          if (vehicleAge >= 5) {
            // Eski S tronic - DSG riski yüksek ama premium parça daha pahalı
            transFactor = 0.87; // S tronic (DSG) riski - premium onarım (-%13)
          } else {
            // Yeni S tronic - orta risk
            transFactor = 0.92; // Yeni DSG orta risk (-%8)
          }
        } else if (model == 'B4') {
          // A4: Multitronic (ESKİ) + S tronic + Tiptronic (QUATTRO)
          if (hasQuattro && vehicleAge >= 8) {
            // Quattro + Tiptronic (Tork Konvertörlü) - EN GÜVENİLİR!
            transFactor = 1.19; // Tiptronic güvenilirlik + Quattro premyumu (+%19)
          } else if (vehicleAge >= 8 && vehicleAge <= 12) {
            // ESKİ NESİL (B8) - MULTİTRONİC CVT TUZAĞI!
            // CVT gibi ama ÇOK yüksek arıza riski
            transFactor = 0.79; // Multitronic CVT - YÜKSEK RİSK (-%21)
          } else if (vehicleAge >= 5) {
            // Orta yaş S tronic - DSG riski
            transFactor = 0.85; // S tronic (DSG) riski (-%15)
          } else {
            // Yeni S tronic - orta risk
            transFactor = 0.91; // Yeni DSG orta risk (-%9)
          }
        } else if (model == 'B6') {
          // A6: S tronic + Tiptronic (QUATTRO 3.0 V6)
          if (hasQuattro && vehicleAge >= 5) {
            // Quattro + Tiptronic (3.0 V6) - GÜVENİLİR + PRESTIJ!
            transFactor = 1.23; // Tiptronic güvenilirlik + Quattro + V6 premyumu (+%23)
          } else if (vehicleAge >= 6) {
            // Eski S tronic - yüksek risk + elektronik risk
            transFactor = 0.82; // S tronic + elektronik çift risk (-%18)
          } else {
            // Yeni S tronic - orta risk
            transFactor = 0.89; // Yeni DSG orta risk (-%11)
          }
        } else if (model == 'B5') {
          // A5: S tronic (DSG) risk - Sportif segment
          if (hasQuattro) {
            // Quattro + S tronic - sportif + 4x4
            transFactor = 0.94; // Quattro primi DSG riskini azaltır (-%6)
          } else if (vehicleAge >= 5) {
            // Eski S tronic - DSG riski
            transFactor = 0.86; // S tronic (DSG) riski (-%14)
          } else {
            // Yeni S tronic - orta risk
            transFactor = 0.91; // Yeni DSG orta risk (-%9)
          }
        }
      }
      // MODEL-SPESİFİK VİTES DEĞERİ (Hanto için - CVT GÜVENİLİRLİĞİ!)
      else if (brand == 'Hanto') {
        final vehicleAge = 2025 - year;
        
        // AWD kontrolü (CR-V için)
        final bool hasAWD = driveType == '4x4';
        
        if (model == 'Vice') {
          // Civic: CVT (10-11. nesil) + eski tork konv. - ÇOK GÜVENİLİR!
          // DSG/Powershift/DCT risklerinden TAM UZAK
          transFactor = 1.15; // CVT güvenilirlik + Honda markası = YÜ KSEK BONUS
          
          // RS/Turbo performans versiyonu ek bonusu
          if (horsepower != null && horsepower >= 170) {
            transFactor *= 1.07; // RS/Turbo performans primi (+%7 ekstra)
          }
        } else if (model == 'VHL') {
          // CR-V: CVT - ÇOK GÜVENİLİR!
          transFactor = 1.16; // CVT güvenilirlik bonusu
          
          // AWD (4x4) ekstra primi
          if (hasAWD) {
            transFactor *= 1.14; // AWD dört çekiş prestij + performans (+%14 ekstra)
          }
        } else if (model == 'Caz') {
          // Jazz: CVT - ÇOK GÜVENİLİR!
          transFactor = 1.13; // CVT güvenilirlik bonusu
          
          // Sihirli koltuk pratiklik primi (her zaman)
          transFactor *= 1.06; // Sihirli koltuk pratiklik (+%6 ekstra)
        }
      }
    }
    
    // HASAR FAKTÖRÜ
    double accidentFactor = hasAccidentRecord ? 0.85 : 1.0; // Hasarlı %15 düşük
    
    // Premium markalarda hasar kayıtlı araç daha büyük değer kaybı
    if (brand == 'Bavora' && hasAccidentRecord) {
      accidentFactor = 0.78; // Bavora hasarlı %22 düşük (onarım pahalı)
    } else if (brand == 'Mercurion' && hasAccidentRecord) {
      if (model == '8 Serisi') {
        accidentFactor = 0.70; // G-Class hasarlı %30 düşük (astronomik onarım)
      } else {
        accidentFactor = 0.76; // Diğer Mercurion modeller %24 düşük
      }
    } else if (brand == 'Audira' && hasAccidentRecord) {
      if (model == 'B6') {
        accidentFactor = 0.74; // A6 hasarlı %26 düşük (karmaşık elektronik + yüksek onarım)
      } else if (model == 'B5') {
        accidentFactor = 0.77; // A5 hasarlı %23 düşük (sportif kasa pahalı onarım)
      } else {
        accidentFactor = 0.80; // B3/B4 hasarlı %20 düşük (premium parça)
      }
    }
    
    // SATICI TİPİ FAKTÖRÜ (Galeriden biraz daha pahalı)
    double sellerFactor = sellerType == 'Galeriden' ? 1.05 : 1.0; // Galeri %5 daha pahalı
    
    // MODEL-SPESİFİK EK FAKTÖRLER
    double trimFactor = 1.0;
    
    // Audira S Line / Teknoloji / Kasa Tipi Faktörleri
    if (brand == 'Audira') {
      // S Line paketi (rastgele %40 ihtimal)
      final bool hasSLine = _random.nextDouble() < 0.40;
      if (hasSLine) {
        if (model == 'B5') {
          trimFactor *= 1.18; // A5 S Line zorunluluğu - maksimum prim (+%18)
        } else if (model == 'B6') {
          trimFactor *= 1.16; // A6 S Line lüks prim (+%16)
        } else if (model == 'B4') {
          trimFactor *= 1.14; // A4 S Line değerli (+%14)
        } else if (model == 'B3') {
          trimFactor *= 1.12; // A3 S Line sportif (+%12)
        }
      }
      
      // Sanal Kokpit / Teknoloji paketi (yeni araçlarda %50 ihtimal)
      if (year != null && year >= 2020 && _random.nextDouble() < 0.50) {
        trimFactor *= 1.08; // Teknoloji primi (+%8)
      }
      
      // Kasa tipi faktörleri
      if (model == 'B3' && bodyType == 'Sedan') {
        trimFactor *= 1.05; // A3 Sedan Türkiye'de popüler (+%5)
      } else if (model == 'B5' && bodyType == 'Hatchback') {
        trimFactor *= 1.07; // A5 Sportback en hızlı satan (+%7)
      }
    }
    

    
    // GENEL HESAPLAMA
    double finalPrice = basePrice * yearFactor * kmFactor * fuelFactor * transFactor * accidentFactor * sellerFactor * trimFactor;
    
    // Rastgele varyasyon ±8% (pazar dinamikleri)
    final variation = ((_random.nextDouble() * 0.16) - 0.08);
    finalPrice = finalPrice * (1 + variation);
    
    return finalPrice.clamp(1.0, basePrice * 1.1);
  }

  /// Rastgele parça durumları oluştur
  Map<String, String> _generatePartConditions() {
    final parts = <String, String>{};
    final conditions = ['orijinal', 'lokal_boyali', 'boyali', 'degisen'];
    
    // %70 oranında orijinal parçalar
    parts['kaput'] = _random.nextInt(100) < 70 ? 'orijinal' : conditions[_random.nextInt(4)];
    parts['tavan'] = _random.nextInt(100) < 85 ? 'orijinal' : conditions[_random.nextInt(3)]; // Tavan değişimi nadir
    parts['bagaj'] = _random.nextInt(100) < 75 ? 'orijinal' : conditions[_random.nextInt(4)];
    parts['sol_on_camurluk'] = _random.nextInt(100) < 80 ? 'orijinal' : conditions[_random.nextInt(4)];
    parts['sag_on_camurluk'] = _random.nextInt(100) < 80 ? 'orijinal' : conditions[_random.nextInt(4)];
    parts['sol_on_kapi'] = _random.nextInt(100) < 85 ? 'orijinal' : conditions[_random.nextInt(3)];
    parts['sag_on_kapi'] = _random.nextInt(100) < 85 ? 'orijinal' : conditions[_random.nextInt(3)];
    parts['sol_arka_kapi'] = _random.nextInt(100) < 85 ? 'orijinal' : conditions[_random.nextInt(3)];
    parts['sag_arka_kapi'] = _random.nextInt(100) < 85 ? 'orijinal' : conditions[_random.nextInt(3)];
    parts['sol_arka_camurluk'] = _random.nextInt(100) < 80 ? 'orijinal' : conditions[_random.nextInt(4)];
    parts['sag_arka_camurluk'] = _random.nextInt(100) < 80 ? 'orijinal' : conditions[_random.nextInt(4)];
    
    return parts;
  }

  /// Açıklama oluştur (model-spesifik)
  String _generateDescription({String? brand, String? model, String? fuelType, String? transmission, int? year, String? driveType, int? horsepower}) {
    // Temel açıklamalar
    final baseDescriptions = [
      'listingDescriptions.base.0'.tr(),
      'listingDescriptions.base.1'.tr(),
      'listingDescriptions.base.2'.tr(),
      'listingDescriptions.base.3'.tr(),
      'listingDescriptions.base.4'.tr(),
      'listingDescriptions.base.5'.tr(),
      'listingDescriptions.base.6'.tr(),
      'listingDescriptions.base.7'.tr(),
    ];
    
    // Model-spesifik ek açıklamalar
    final List<String> extraNotes = [];
    
    // Model-spesifik ek açıklamalar (Otomatik Lookup)
    if (brand != null && model != null) {
      final normalizedModel = model.replaceAll(' ', '_');
      extraNotes.addAll('modelDescriptions.$brand.$normalizedModel'.trList());
    }
    
    // Marka-spesifik teknik detaylar (Yakıt, Vites vb.)
    if (brand == 'Renauva') {
      if (fuelType == 'Dizel') extraNotes.add('modelDescriptions.Renauva.diesel'.tr());
      else if (fuelType == 'Benzin+LPG') extraNotes.add('modelDescriptions.Renauva.lpg'.tr());
      else if (fuelType == 'Hybrid') extraNotes.add('modelDescriptions.Renauva.hybrid'.tr());
      
      if (transmission == 'Otomatik') {
        if (model == 'Tallion') extraNotes.add('modelDescriptions.Renauva.cvt'.tr());
        else if (model == 'Signa') extraNotes.add('modelDescriptions.Renauva.auto'.tr());
        else extraNotes.add('modelDescriptions.Renauva.edc'.tr());
      }
    } else if (brand == 'Volkstar') {
      if (fuelType == 'Dizel') extraNotes.add('modelDescriptions.Volkstar.tdi'.tr());
      if (transmission == 'Otomatik') extraNotes.add('modelDescriptions.Volkstar.dsg'.tr());
    } else if (brand == 'Fialto') {
      if (fuelType == 'Dizel') extraNotes.add('modelDescriptions.Fialto.multijet'.tr());
      else if (fuelType == 'Hybrid') extraNotes.add('modelDescriptions.Fialto.hybrid'.tr());
      
      if (transmission == 'Otomatik') {
        if (model == 'Lagua' || model == 'Zorno') extraNotes.add('modelDescriptions.Fialto.dualogic'.tr());
        else extraNotes.add('modelDescriptions.Fialto.auto'.tr());
      }
    } else if (brand == 'Oplon') {
      if (fuelType == 'Dizel') extraNotes.add('modelDescriptions.Oplon.cdti'.tr());
      
      if (transmission == 'Otomatik') {
        if (model == 'Lorisa' && year != null && year < 2020) extraNotes.add('modelDescriptions.Oplon.easytronic'.tr());
        else extraNotes.add('modelDescriptions.Oplon.auto'.tr());
      }
    } else if (brand == 'Bavora') {
      if (fuelType == 'Dizel') extraNotes.add('modelDescriptions.Bavora.diesel'.tr());
      else if (fuelType == 'Hybrid') extraNotes.add('modelDescriptions.Bavora.hybrid'.tr());
      
      if (transmission == 'Otomatik') {
        if (model == 'A Serisi' && year != null && year >= 2020) extraNotes.add('modelDescriptions.Bavora.dct'.tr());
        else extraNotes.add('modelDescriptions.Bavora.zf'.tr());
      }
      extraNotes.add('modelDescriptions.Bavora.rwd'.tr());
    } else if (brand == 'Fortran') {
      if (fuelType == 'Dizel') {
        if (model == 'Odak' || model == 'Tupa') extraNotes.add('modelDescriptions.Fortran.ecoblue'.tr());
        else if (model == 'Vista') extraNotes.add('modelDescriptions.Fortran.tdci'.tr());
        else if (model == 'Avger') extraNotes.add('modelDescriptions.Fortran.biturbo'.tr());
      } else if (fuelType == 'Hybrid') extraNotes.add('modelDescriptions.Fortran.hybrid'.tr());
      else if (fuelType == 'Benzin') extraNotes.add('modelDescriptions.Fortran.ecoboost'.tr());
      
      if (transmission == 'Otomatik') {
        if (year != null && year >= 2018) {
          if (model == 'Avger') extraNotes.add('modelDescriptions.Fortran.auto10'.tr());
          else extraNotes.add('modelDescriptions.Fortran.auto8'.tr());
        } else {
          extraNotes.add('modelDescriptions.Fortran.powershift'.tr());
        }
      }
      if (model == 'Avger') extraNotes.add('modelDescriptions.Fortran.4x4'.tr());
    } else if (brand == 'Mercurion') {
      if (fuelType == 'Dizel') extraNotes.add('modelDescriptions.Mercurion.diesel'.tr());
      else if (fuelType == 'Hybrid') extraNotes.add('modelDescriptions.Mercurion.hybrid'.tr());
      
      if (transmission == 'Otomatik') {
        if (model == '1 Serisi' || model == 'GJE') extraNotes.add('modelDescriptions.Mercurion.dct'.tr());
        else extraNotes.add('modelDescriptions.Mercurion.tronic'.tr());
      }
      if (model == '8 Serisi') extraNotes.add('modelDescriptions.Mercurion.4matic'.tr());
      else extraNotes.add('modelDescriptions.Mercurion.rwd'.tr());
    } else if (brand == 'Hundar') {
      if (fuelType == 'Dizel') extraNotes.add('modelDescriptions.Hundar.crdi'.tr());
      else if (fuelType == 'Hybrid') extraNotes.add('modelDescriptions.Hundar.hybrid'.tr());
      
      if (transmission == 'Otomatik') {
        if (year != null && year >= 2019) extraNotes.add('modelDescriptions.Hundar.dct'.tr());
        else extraNotes.add('modelDescriptions.Hundar.auto'.tr());
      }
    } else if (brand == 'Koyoro') {
      if (fuelType == 'Hybrid') extraNotes.add('modelDescriptions.Koyoro.hybrid'.tr());
      else if (fuelType == 'Dizel') extraNotes.add('modelDescriptions.Koyoro.diesel'.tr());
      
      if (transmission == 'Otomatik') {
        if (fuelType == 'Hybrid') extraNotes.add('modelDescriptions.Koyoro.cvt_hybrid'.tr());
        else if ((fuelType == 'Dizel' || model == 'Karma') && year != null && year <= 2015) extraNotes.add('modelDescriptions.Koyoro.mmt'.tr());
        else extraNotes.add('modelDescriptions.Koyoro.cvt'.tr());
      }
    } else if (brand == 'Audira') {
      if (fuelType == 'Dizel') {
        if (model == 'B6') extraNotes.add('modelDescriptions.Audira.tdi_high'.tr());
        else extraNotes.add('modelDescriptions.Audira.tdi'.tr());
      }
      if (driveType == '4x4') extraNotes.add('modelDescriptions.Audira.quattro'.tr());
      
      if (transmission == 'Otomatik' && year != null) {
        final vehicleAge = 2025 - year;
        if (driveType == '4x4' && vehicleAge >= 5) extraNotes.add('modelDescriptions.Audira.tiptronic'.tr());
        else if (model == 'B4' && vehicleAge >= 8 && vehicleAge <= 12) extraNotes.add('modelDescriptions.Audira.multitronic'.tr());
        else if (vehicleAge >= 5) extraNotes.add('modelDescriptions.Audira.stronic_check'.tr());
        else extraNotes.add('modelDescriptions.Audira.stronic'.tr());
      }
    } else if (brand == 'Hanto') {
      if (fuelType == 'Hybrid') {
        if (model == 'VHL') extraNotes.add('modelDescriptions.Hanto.hybrid_vhl'.tr());
        else if (model == 'Caz') extraNotes.add('modelDescriptions.Hanto.hybrid_caz'.tr());
      } else if (fuelType == 'Benzin+LPG') extraNotes.add('modelDescriptions.Hanto.lpg'.tr());
      
      if (driveType == '4x4') extraNotes.add('modelDescriptions.Hanto.awd'.tr());
      if (transmission == 'Otomatik') extraNotes.add('modelDescriptions.Hanto.cvt'.tr());
      if (model == 'Vice' && horsepower != null && horsepower >= 170) extraNotes.add('modelDescriptions.Hanto.rs'.tr());
    }
    
    // Ana açıklama + ek notlar
    final baseDesc = baseDescriptions[_random.nextInt(baseDescriptions.length)];
    
    if (extraNotes.isNotEmpty && _random.nextBool()) {
      final extraNote = extraNotes[_random.nextInt(extraNotes.length)];
      return '$baseDesc $extraNote';
    }
    
    return baseDesc;
  }

  /// Aktif ilanları al (marka ve model filtrelemesi ile)
  List<Vehicle> getActiveListings({String? brand, String? model}) {
    var listings = _activeListings.map((l) => l.vehicle).toList();
    
    // Marka filtresi
    if (brand != null) {
      listings = listings.where((v) => v.brand == brand).toList();
    }
    
    // Model filtresi
    if (model != null) {
      listings = listings.where((v) => v.model == model).toList();
    }
    
    return listings;
  }

  /// Marka-model eşleşmelerini döndür
  Map<String, List<String>> getModelsByBrand() {
    return Map.from(_modelsByBrand);
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
  /// İlanı güncelle (Ekspertiz sonrası vb.)
  void updateListing(Vehicle updatedVehicle) {
    final index = _activeListings.indexWhere((l) => l.vehicle.id == updatedVehicle.id);
    if (index != -1) {
      final oldListing = _activeListings[index];
      _activeListings[index] = MarketListing(
        vehicle: updatedVehicle,
        createdDay: oldListing.createdDay,
        expiryDay: oldListing.expiryDay,
      );
    }
  }

  /// ID'ye göre araç getir (Favoriler için güncel veri)
  Vehicle? getVehicleById(String id) {
    final index = _activeListings.indexWhere((l) => l.vehicle.id == id);
    if (index != -1) {
      return _activeListings[index].vehicle;
    }
    return null;
  }

  /// İlanı kaldır (Satın alma sonrası)
  void removeListing(String vehicleId) {
    _activeListings.removeWhere((l) => l.vehicle.id == vehicleId);
  }

  /// Marka ve modele göre araç resmi seç (Ölçeklenebilir yapı)
  String? _getVehicleImage(String brand, String model) {
    // 1. Özel Durumlar (Manuel tanımlamalar)

    
    // 2. Klasör Bazlı Yapı (Yeni Standart)
    // Örn: assets/car_images/bavora/e_series/e_series_1.png
    if (brand == 'Bavora') {
      if (model == 'E Serisi') {
        // 1-6 arası rastgele resim
        final index = 1 + _random.nextInt(6);
        return 'assets/car_images/bavora/e_series/e_series_$index.png';
      } else if (model == 'A Serisi') {
        // 1-6 arası rastgele resim
        final index = 1 + _random.nextInt(6);
        return 'assets/car_images/bavora/a_series/a_series_$index.png';
      } else if (model == 'D Serisi') {
        // 1-6 arası rastgele resim
        final index = 1 + _random.nextInt(6);
        return 'assets/car_images/bavora/d_series/d_series_$index.png';
      } else {
        // Diğer Bavora modelleri (şimdilik eski yapı - C Serisi vb.)
        // Eski yapı: assets/car_images/bavora/bavora_X.png
        final index = 1 + _random.nextInt(6);
        return 'assets/car_images/bavora/bavora_$index.png';
      }
    }
    
    // 3. Renauva Slim (Yeni Yapı)
    if (brand == 'Renauva' && model == 'Slim') {
      // 1-6 arası rastgele resim (Refined Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/renauva/slim/slim_$index.png';
    }
    
    // 4. Renauva Magna (Yeni Yapı)
    if (brand == 'Renauva' && model == 'Magna') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/renauva/magna/magna_$index.png';
    }

    // 5. Renauva Flow (Yeni Yapı)
    if (brand == 'Renauva' && model == 'Flow') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/renauva/flow/flow_$index.png';
    }

    // 6. Renauva Signa (Yeni Yapı)
    if (brand == 'Renauva' && model == 'Signa') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/renauva/signa/signa_$index.png';
    }

    // 7. Renauva Tallion (Yeni Yapı)
    if (brand == 'Renauva' && model == 'Tallion') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/renauva/tallion/tallion_$index.png';
    }

    // 8. Fortran Odak (Yeni Yapı)
    if (brand == 'Fortran' && model == 'Odak') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/fortran/odak/odak_$index.png';
    }

    // 9. Fortran Vista (Yeni Yapı)
    if (brand == 'Fortran' && model == 'Vista') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/fortran/vista/vista_$index.png';
    }

    // 10. Fortran Avger (Yeni Yapı)
    if (brand == 'Fortran' && model == 'Avger') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/fortran/avger/avger_$index.png';
    }

    // 11. Fortran Tupa (Yeni Yapı)
    if (brand == 'Fortran' && model == 'Tupa') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/fortran/tupa/tupa_$index.png';
    }

    // 12. Oplon Mornitia (Yeni Yapı)
    if (brand == 'Oplon' && model == 'Mornitia') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/oplon/mornitia/mornitia_$index.png';
    }

    // 13. Oplon Lorisa (Yeni Yapı)
    if (brand == 'Oplon' && model == 'Lorisa') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/oplon/lorisa/lorisa_$index.png';
    }

    // 14. Oplon Tasra (Yeni Yapı)
    if (brand == 'Oplon' && model == 'Tasra') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/oplon/tasra/tasra_$index.png';
    }

    // 15. Fialto Agna (Yeni Yapı)
    if (brand == 'Fialto' && model == 'Agna') {
      // 1-4 arası rastgele resim (Smart Split - 2 merged row filtered)
      final index = 1 + _random.nextInt(4);
      return 'assets/car_images/fialto/agna/agna_$index.png';
    }

    // 16. Fialto Lagua (Yeni Yapı)
    if (brand == 'Fialto' && model == 'Lagua') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/fialto/lagua/lagua_$index.png';
    }

    // 17. Fialto Zorno (Yeni Yapı)
    if (brand == 'Fialto' && model == 'Zorno') {
      // 1-6 arası rastgele resim (Smart Split)
      final index = 1 + _random.nextInt(6);
      return 'assets/car_images/fialto/zorno/zorno_$index.png';
    }

    // 18. Varsayılan Tek Resim Yapısı
    // Örn: assets/car_images/Renauva/Slim.png
    final safeModelName = model.replaceAll(' ', '_');
    return 'assets/car_images/$brand/$safeModelName.png';
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

