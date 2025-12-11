import 'package:uuid/uuid.dart';

enum ActivityType {
  purchase, // Araç satın alma
  sale, // Araç satışı
  rental, // Kira geliri
  levelUp, // Seviye atlama
  taxi, // Taksi oyunu kazancı
  dailyLogin, // Günlük giriş bonusu
  expense, // Genel gider
  income, // Genel gelir
}

class Activity {
  final String id;
  final String userId;
  final ActivityType type;
  final String title;
  final String description;
  final double? amount; // Pozitif: Gelir, Negatif: Gider
  final DateTime date;

  Activity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.amount,
    required this.date,
  });

  factory Activity.create({
    required String userId,
    required ActivityType type,
    required String title,
    required String description,
    double? amount,
  }) {
    return Activity(
      id: const Uuid().v4(),
      userId: userId,
      type: type,
      title: title,
      description: description,
      amount: amount,
      date: DateTime.now(),
    );
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: ActivityType.values[json['type'] as int],
      title: json['title'] as String,
      description: json['description'] as String,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.index,
      'title': title,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }
}
