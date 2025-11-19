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

