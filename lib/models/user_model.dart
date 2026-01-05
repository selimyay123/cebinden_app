import 'package:uuid/uuid.dart';

class User {
  final String id; // Benzersiz kullanıcı ID'si
  final String username;
  final String password; // Hashlenmiş şifre
  final DateTime registeredAt;
  final double balance; // Kullanıcının mevcut bakiyesi (TL)
  final double gold; // Kullanıcının altın miktarı (1 Altın = 1,000,000 TL)
  final double profitLossPercentage; // Kar/Zarar yüzdesi
  final String? profileImageUrl; // Profil resmi URL'i (opsiyonel)
  final String currency; // Para birimi: 'TL', 'USD', 'EUR'
  final String authProvider; // Giriş yöntemi: 'email' veya 'google'
  final String? googleUserId; // Google kullanıcı ID'si (Google Sign-In için)
  final String? appleUserId; // Apple kullanıcı ID'si (Apple Sign In için)
  final String? email; // E-posta adresi (Google Sign-In için)
  final bool isBanned; // Kullanıcı yasaklı mı?
  final bool isTutorialCompleted; // Tutorial tamamlandı mı?
  
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
  final DateTime? lastDailyRewardDate; // Son günlük ödül alınan tarih
  final int garageLimit; // Garaj limiti
  final List<String> collectedBrandRewards; // Toplanan marka ödülleri

  // ========== GÜNLÜK İSTATİSTİKLER ==========
  final double dailyStartingBalance; // Gün başlangıcındaki bakiye
  final DateTime? lastDailyResetDate; // Son günlük sıfırlama tarihi

  // ========== GALERİ SİSTEMİ ==========
  final bool ownsGallery; // Galeri sahibi mi?
  final DateTime? galleryPurchaseDate; // Galeri satın alma tarihi
  final double totalRentalIncome; // Toplam kiralama geliri
  final double lastDailyRentalIncome; // Son günlük kiralama geliri

  // ========== YETENEK SİSTEMİ ==========
  final int skillPoints; // Mevcut yetenek puanı
  final Map<String, int> skills; // Yetenek ID -> Seviye
  final Map<String, int> dailySkillUses; // Yetenek ID -> Günlük kullanım sayısı
  final List<String> purchasedAnimatedPPs; // Satın alınan animasyonlu profil resimleri
  final String? activeAnimatedPP; // Aktif animasyonlu profil resmi
  final int lastSkillUseDay; // Son kullanım günü (sıfırlama için)
  
  // ========== KULLANICI ADI DEĞİŞİKLİĞİ ==========
  final int usernameChangeCount; // Kullanıcı adı değiştirme sayısı
  final DateTime? lastUsernameChangeDate; // Son kullanıcı adı değiştirme tarihi

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.registeredAt,
    this.balance = 1000000.0, // Varsayılan başlangıç parası: 1,000,000 TL
    this.gold = 0.0, // Varsayılan başlangıç altını: 0
    this.profitLossPercentage = 0.0, // Başlangıçta kar/zarar yok
    this.profileImageUrl,
    this.currency = 'TL', // Varsayılan para birimi
    this.authProvider = 'email', // Varsayılan giriş yöntemi
    this.googleUserId,
    this.appleUserId,
    this.email,
    this.isBanned = false, // Varsayılan olarak yasaklı değil
    this.isTutorialCompleted = false, // Varsayılan olarak tamamlanmadı
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
    this.lastDailyRewardDate,
    this.garageLimit = 3, // Varsayılan limit
    // Günlük İstatistikler
    this.dailyStartingBalance = 1000000.0,
    this.lastDailyResetDate,
    // Galeri Sistemi
    this.ownsGallery = false,
    this.galleryPurchaseDate,
    this.totalRentalIncome = 0.0,
    this.lastDailyRentalIncome = 0.0,
    // Yetenek Sistemi
    this.skillPoints = 0,
    this.skills = const {},
    this.dailySkillUses = const {},
    this.lastSkillUseDay = 0,
    this.collectedBrandRewards = const [],
    this.purchasedAnimatedPPs = const [],
    this.activeAnimatedPP,
    this.usernameChangeCount = 0,
    this.lastUsernameChangeDate,
  });

  // Yeni kullanıcı oluşturma factory
  factory User.create({
    required String username,
    required String password,
  }) {
    return User(
      id: const Uuid().v4(), // Benzersiz ID üret
      username: username,
      password: password,
      registeredAt: DateTime.now(),
      usernameChangeCount: 0,
    );
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
    
    // 🆕 Level Cap: Max 100
    if (level > 100) return 100;
    
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

  /// Toplam Kar/Zarar (Varsayılan başlangıç parası 1M TL kabul edilerek)
  double get totalProfitLoss => balance - 1000000.0;

  // JSON'dan User nesnesi oluşturma
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      balance: (json['balance'] as num?)?.toDouble() ?? 1000000.0,
      gold: (json['gold'] as num?)?.toDouble() ?? 0.0,
      profitLossPercentage: (json['profitLossPercentage'] as num?)?.toDouble() ?? 0.0,
      profileImageUrl: json['profileImageUrl'] as String?,
      currency: 'TL', // Always force TL
      authProvider: json['authProvider'] as String? ?? 'email',
      googleUserId: json['googleUserId'] as String?,
      appleUserId: json['appleUserId'] as String?,
      email: json['email'] as String?,
      isBanned: json['isBanned'] as bool? ?? false,
      isTutorialCompleted: json['isTutorialCompleted'] as bool? ?? true, // Eski kullanıcılar için varsayılan true
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
      lastDailyRewardDate: json['lastDailyRewardDate'] != null 
          ? DateTime.parse(json['lastDailyRewardDate']) 
          : null,
      garageLimit: json['garageLimit'] as int? ?? 3,
      // Günlük İstatistikler
      dailyStartingBalance: (json['dailyStartingBalance'] as num?)?.toDouble() ?? (json['balance'] as num?)?.toDouble() ?? 1000000.0,
      lastDailyResetDate: json['lastDailyResetDate'] != null 
          ? DateTime.parse(json['lastDailyResetDate']) 
          : null,
      // Galeri Sistemi
      ownsGallery: json['ownsGallery'] as bool? ?? false,
      galleryPurchaseDate: json['galleryPurchaseDate'] != null 
          ? DateTime.parse(json['galleryPurchaseDate']) 
          : null,
      totalRentalIncome: (json['totalRentalIncome'] as num?)?.toDouble() ?? 0.0,
      lastDailyRentalIncome: (json['lastDailyRentalIncome'] as num?)?.toDouble() ?? 0.0,
      // Yetenek Sistemi
      skillPoints: json['skillPoints'] as int? ?? 0,
      skills: (json['skills'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v as int),
          ) ??
          const {},
      dailySkillUses: (json['dailySkillUses'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v as int),
          ) ??
          const {},
      lastSkillUseDay: json['lastSkillUseDay'] as int? ?? 0,
      collectedBrandRewards: (json['collectedBrandRewards'] as List?)?.cast<String>() ?? const [],
      purchasedAnimatedPPs: (json['purchasedAnimatedPPs'] as List?)?.cast<String>() ?? const [],
      activeAnimatedPP: json['activeAnimatedPP'] as String?,
      usernameChangeCount: json['usernameChangeCount'] as int? ?? 0,
      lastUsernameChangeDate: json['lastUsernameChangeDate'] != null 
          ? DateTime.parse(json['lastUsernameChangeDate']) 
          : null,
    );
  }

  // User nesnesini JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'registeredAt': registeredAt.toIso8601String(),
      'balance': balance,
      'gold': gold,
      'profitLossPercentage': profitLossPercentage,
      'profileImageUrl': profileImageUrl,
      'currency': currency,
      'authProvider': authProvider,
      'googleUserId': googleUserId,
      'appleUserId': appleUserId,
      'email': email,
      'isBanned': isBanned,
      'isTutorialCompleted': isTutorialCompleted,
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
      'lastDailyRewardDate': lastDailyRewardDate?.toIso8601String(),
      'garageLimit': garageLimit,
      // Günlük İstatistikler
      'dailyStartingBalance': dailyStartingBalance,
      'lastDailyResetDate': lastDailyResetDate?.toIso8601String(),
      // Galeri Sistemi
      'ownsGallery': ownsGallery,
      'galleryPurchaseDate': galleryPurchaseDate?.toIso8601String(),
      'totalRentalIncome': totalRentalIncome,
      'lastDailyRentalIncome': lastDailyRentalIncome,
      // Yetenek Sistemi
      'skillPoints': skillPoints,
      'skills': skills,
      'dailySkillUses': dailySkillUses,
      'lastSkillUseDay': lastSkillUseDay,
      'collectedBrandRewards': collectedBrandRewards,
      'purchasedAnimatedPPs': purchasedAnimatedPPs,
      'activeAnimatedPP': activeAnimatedPP,
      'usernameChangeCount': usernameChangeCount,
      'lastUsernameChangeDate': lastUsernameChangeDate?.toIso8601String(),
    };
  }

  // copyWith metodu
  User copyWith({
    String? id,
    String? username,
    String? password,
    DateTime? registeredAt,
    double? balance,
    double? gold,
    double? profitLossPercentage,
    String? profileImageUrl,
    String? currency,
    String? authProvider,
    String? googleUserId,
    String? appleUserId,
    String? email,
    bool? isBanned,
    bool? isTutorialCompleted,
    int? xp,
    int? level,
    int? totalVehiclesBought,
    int? totalVehiclesSold,
    int? totalOffersMade,
    int? totalOffersReceived,
    int? successfulNegotiations,
    int? consecutiveLoginDays,
    DateTime? lastLoginDate,
    DateTime? lastDailyRewardDate,
    int? garageLimit,
    double? dailyStartingBalance,
    DateTime? lastDailyResetDate,
    bool? ownsGallery,
    DateTime? galleryPurchaseDate,
    double? totalRentalIncome,
    double? lastDailyRentalIncome,
    int? skillPoints,
    Map<String, int>? skills,
    Map<String, int>? dailySkillUses,
    int? lastSkillUseDay,
    List<String>? collectedBrandRewards,
    List<String>? purchasedAnimatedPPs,
    String? activeAnimatedPP,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      registeredAt: registeredAt ?? this.registeredAt,
      balance: balance ?? this.balance,
      gold: gold ?? this.gold,
      profitLossPercentage: profitLossPercentage ?? this.profitLossPercentage,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      currency: currency ?? this.currency,
      authProvider: authProvider ?? this.authProvider,
      googleUserId: googleUserId ?? this.googleUserId,
      appleUserId: appleUserId ?? this.appleUserId,
      email: email ?? this.email,
      isBanned: isBanned ?? this.isBanned,
      isTutorialCompleted: isTutorialCompleted ?? this.isTutorialCompleted,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      totalVehiclesBought: totalVehiclesBought ?? this.totalVehiclesBought,
      totalVehiclesSold: totalVehiclesSold ?? this.totalVehiclesSold,
      totalOffersMade: totalOffersMade ?? this.totalOffersMade,
      totalOffersReceived: totalOffersReceived ?? this.totalOffersReceived,
      successfulNegotiations: successfulNegotiations ?? this.successfulNegotiations,
      consecutiveLoginDays: consecutiveLoginDays ?? this.consecutiveLoginDays,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      lastDailyRewardDate: lastDailyRewardDate ?? this.lastDailyRewardDate,
      garageLimit: garageLimit ?? this.garageLimit,
      dailyStartingBalance: dailyStartingBalance ?? this.dailyStartingBalance,
      lastDailyResetDate: lastDailyResetDate ?? this.lastDailyResetDate,
      ownsGallery: ownsGallery ?? this.ownsGallery,
      galleryPurchaseDate: galleryPurchaseDate ?? this.galleryPurchaseDate,
      totalRentalIncome: totalRentalIncome ?? this.totalRentalIncome,
      lastDailyRentalIncome: lastDailyRentalIncome ?? this.lastDailyRentalIncome,
      skillPoints: skillPoints ?? this.skillPoints,
      skills: skills ?? this.skills,
      dailySkillUses: dailySkillUses ?? this.dailySkillUses,
      lastSkillUseDay: lastSkillUseDay ?? this.lastSkillUseDay,
      collectedBrandRewards: collectedBrandRewards ?? this.collectedBrandRewards,
      purchasedAnimatedPPs: purchasedAnimatedPPs ?? this.purchasedAnimatedPPs,
      activeAnimatedPP: activeAnimatedPP ?? this.activeAnimatedPP,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

