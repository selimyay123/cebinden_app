import 'package:uuid/uuid.dart';

class User {
  final String id; // Benzersiz kullanıcı ID'si
  final String username;
  final String password; // Hashlenmiş şifre
  final String gender; // 'Erkek' veya 'Kadın'
  final DateTime birthDate;
  final DateTime registeredAt;
  final double balance; // Kullanıcının mevcut bakiyesi (TL)
  final double gold; // Kullanıcının altın miktarı (1 Altın = 1,000,000 TL)
  final double profitLossPercentage; // Kar/Zarar yüzdesi
  final String? profileImageUrl; // Profil resmi URL'i (opsiyonel)
  final String currency; // Para birimi: 'TL', 'USD', 'EUR'
  final String authProvider; // Giriş yöntemi: 'email' veya 'google'
  final String? googleUserId; // Google kullanıcı ID'si (Google Sign-In için)
  final String? email; // E-posta adresi (Google Sign-In için)
  
  // ========== XP SİSTEMİ ==========
  final int xp; // Toplam deneyim puanı
  final int level; // Kullanıcı seviyesi
  final int totalVehiclesBought; // Toplam satın alınan araç sayısı
  final int totalVehiclesSold; // Toplam satılan araç sayısı
  final int totalOffersMade; // Toplam yapılan teklif sayısı
  final int totalOffersReceived; // Toplam alınan teklif sayısı
  final int successfulNegotiations; // Başarılı pazarlık sayısı
  final int consecutiveLoginDays; // Ardışık giriş günü sayısı
  final DateTime? lastLoginDate; // Son giriş tarihi

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.gender,
    required this.birthDate,
    required this.registeredAt,
    this.balance = 1000000.0, // Varsayılan başlangıç parası: 1,000,000 TL
    this.gold = 0.0, // Varsayılan başlangıç altını: 0
    this.profitLossPercentage = 0.0, // Başlangıçta kar/zarar yok
    this.profileImageUrl,
    this.currency = 'TL', // Varsayılan para birimi
    this.authProvider = 'email', // Varsayılan giriş yöntemi
    this.googleUserId,
    this.email,
    // XP Sistemi
    this.xp = 0,
    this.level = 1,
    this.totalVehiclesBought = 0,
    this.totalVehiclesSold = 0,
    this.totalOffersMade = 0,
    this.totalOffersReceived = 0,
    this.successfulNegotiations = 0,
    this.consecutiveLoginDays = 0,
    this.lastLoginDate,
  });

  // Yeni kullanıcı oluşturma factory
  factory User.create({
    required String username,
    required String password,
    required String gender,
    required DateTime birthDate,
  }) {
    return User(
      id: const Uuid().v4(), // Benzersiz ID üret
      username: username,
      password: password,
      gender: gender,
      birthDate: birthDate,
      registeredAt: DateTime.now(),
    );
  }

  // Yaşı hesapla
  int get age {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // ========== XP SİSTEMİ HESAPLAMALARI ==========
  
  /// XP'den seviye hesaplama (Matematiksel formül)
  /// Her seviye için gereken XP: level^2 * 100
  static int calculateLevel(int xp) {
    int level = 1;
    int requiredXp = 100;
    int totalXp = 0;
    
    while (totalXp + requiredXp <= xp) {
      totalXp += requiredXp;
      level++;
      requiredXp = level * level * 100;
    }
    
    return level;
  }
  
  /// Belirli bir seviye için gereken toplam XP
  static int xpForLevel(int level) {
    int totalXp = 0;
    for (int i = 1; i < level; i++) {
      totalXp += i * i * 100;
    }
    return totalXp;
  }
  
  /// Bir sonraki seviye için gereken XP miktarı
  static int xpForNextLevel(int level) {
    return level * level * 100;
  }
  
  /// Mevcut seviyedeki ilerleme yüzdesi (0.0 - 1.0)
  double get levelProgress {
    int currentLevelXp = User.xpForLevel(level);
    int nextLevelXp = User.xpForNextLevel(level);
    int progressXp = xp - currentLevelXp;
    
    return (progressXp / nextLevelXp).clamp(0.0, 1.0);
  }
  
  /// Bir sonraki seviyeye kalan XP
  int get xpToNextLevel {
    int currentLevelXp = User.xpForLevel(level);
    int nextLevelTotalXp = currentLevelXp + User.xpForNextLevel(level);
    return nextLevelTotalXp - xp;
  }

  // JSON'dan User nesnesi oluşturma
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      gender: json['gender'] as String,
      birthDate: DateTime.parse(json['birthDate'] as String),
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      balance: (json['balance'] as num?)?.toDouble() ?? 1000000.0,
      gold: (json['gold'] as num?)?.toDouble() ?? 0.0,
      profitLossPercentage: (json['profitLossPercentage'] as num?)?.toDouble() ?? 0.0,
      profileImageUrl: json['profileImageUrl'] as String?,
      currency: json['currency'] as String? ?? 'TL',
      authProvider: json['authProvider'] as String? ?? 'email',
      googleUserId: json['googleUserId'] as String?,
      email: json['email'] as String?,
      // XP Sistemi
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      totalVehiclesBought: json['totalVehiclesBought'] as int? ?? 0,
      totalVehiclesSold: json['totalVehiclesSold'] as int? ?? 0,
      totalOffersMade: json['totalOffersMade'] as int? ?? 0,
      totalOffersReceived: json['totalOffersReceived'] as int? ?? 0,
      successfulNegotiations: json['successfulNegotiations'] as int? ?? 0,
      consecutiveLoginDays: json['consecutiveLoginDays'] as int? ?? 0,
      lastLoginDate: json['lastLoginDate'] != null 
          ? DateTime.parse(json['lastLoginDate'] as String)
          : null,
    );
  }

  // User nesnesini JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'gender': gender,
      'birthDate': birthDate.toIso8601String(),
      'registeredAt': registeredAt.toIso8601String(),
      'balance': balance,
      'gold': gold,
      'profitLossPercentage': profitLossPercentage,
      'profileImageUrl': profileImageUrl,
      'currency': currency,
      'authProvider': authProvider,
      'googleUserId': googleUserId,
      'email': email,
      // XP Sistemi
      'xp': xp,
      'level': level,
      'totalVehiclesBought': totalVehiclesBought,
      'totalVehiclesSold': totalVehiclesSold,
      'totalOffersMade': totalOffersMade,
      'totalOffersReceived': totalOffersReceived,
      'successfulNegotiations': successfulNegotiations,
      'consecutiveLoginDays': consecutiveLoginDays,
      'lastLoginDate': lastLoginDate?.toIso8601String(),
    };
  }

  // copyWith metodu
  User copyWith({
    String? id,
    String? username,
    String? password,
    String? gender,
    DateTime? birthDate,
    DateTime? registeredAt,
    double? balance,
    double? gold,
    double? profitLossPercentage,
    String? profileImageUrl,
    String? currency,
    String? authProvider,
    String? googleUserId,
    String? email,
    int? xp,
    int? level,
    int? totalVehiclesBought,
    int? totalVehiclesSold,
    int? totalOffersMade,
    int? totalOffersReceived,
    int? successfulNegotiations,
    int? consecutiveLoginDays,
    DateTime? lastLoginDate,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      registeredAt: registeredAt ?? this.registeredAt,
      balance: balance ?? this.balance,
      gold: gold ?? this.gold,
      profitLossPercentage: profitLossPercentage ?? this.profitLossPercentage,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      currency: currency ?? this.currency,
      authProvider: authProvider ?? this.authProvider,
      googleUserId: googleUserId ?? this.googleUserId,
      email: email ?? this.email,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      totalVehiclesBought: totalVehiclesBought ?? this.totalVehiclesBought,
      totalVehiclesSold: totalVehiclesSold ?? this.totalVehiclesSold,
      totalOffersMade: totalOffersMade ?? this.totalOffersMade,
      totalOffersReceived: totalOffersReceived ?? this.totalOffersReceived,
      successfulNegotiations: successfulNegotiations ?? this.successfulNegotiations,
      consecutiveLoginDays: consecutiveLoginDays ?? this.consecutiveLoginDays,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, gender: $gender, age: $age)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

