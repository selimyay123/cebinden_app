/// Uygulama içi bildirim modeli
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data; // Ek bilgiler (offerId, vehicleId vs)
  
  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  // JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString(),
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'data': data,
    };
  }

  // JSON'dan oluştur
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['userId'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      title: json['title'],
      message: json['message'],
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    );
  }

  // Copy with
  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
}

/// Bildirim tipleri
enum NotificationType {
  newOffer,        // Yeni teklif geldi
  offerAccepted,   // Teklifiniz kabul edildi
  offerRejected,   // Teklifiniz reddedildi
  vehicleSold,     // Aracınız satıldı
  priceChange,     // Fiyat değişikliği
  system,          // Sistem bildirimi
}

/// İkonlar ve renkler için extension
extension NotificationTypeExtension on NotificationType {
  String get icon {
    switch (this) {
      case NotificationType.newOffer:
        return '💰';
      case NotificationType.offerAccepted:
        return '✅';
      case NotificationType.offerRejected:
        return '❌';
      case NotificationType.vehicleSold:
        return '🎉';
      case NotificationType.priceChange:
        return '📉';
      case NotificationType.system:
        return '🔔';
    }
  }
  
  String get colorName {
    switch (this) {
      case NotificationType.newOffer:
        return 'blue';
      case NotificationType.offerAccepted:
        return 'green';
      case NotificationType.offerRejected:
        return 'red';
      case NotificationType.vehicleSold:
        return 'purple';
      case NotificationType.priceChange:
        return 'orange';
      case NotificationType.system:
        return 'grey';
    }
  }
}

