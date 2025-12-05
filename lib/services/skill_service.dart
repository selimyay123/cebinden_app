import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Basitleştirilmiş Yetenek Modeli
class Skill {
  final String id;
  final String nameKey; // Localization key
  final String descKey; // Localization key
  final int cost;
  final String emoji; // Emoji icon
  final Color primaryColor;
  final Color secondaryColor;
  final int maxLevel; // Maksimum seviye (1 = tek seviye)
  
  const Skill({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.cost,
    required this.emoji,
    required this.primaryColor,
    required this.secondaryColor,
    this.maxLevel = 1,
  });
}

class SkillService {
  // ============================================================================
  // YENİ YETENEK LİSTESİ (6 Yetenek)
  // ============================================================================
  
  static const List<Skill> skills = [
    // ============================================================================
    // TAMAMEN ENTEGRE VE ÇALIŞAN YETENEKLER
    // ============================================================================
    
    // 1. İtibar - Gelen teklifler %10 daha yüksek
    Skill(
      id: 'reputation',
      nameKey: 'skills.reputation',
      descKey: 'skills.reputationDesc',
      cost: 1,
      emoji: '🏆',
      primaryColor: Color(0xFF9C27B0),
      secondaryColor: Color(0xFFAB47BC),
    ),
    
    // 2. Garaj Genişletme - +2 araç kapasitesi
    Skill(
      id: 'garage_expansion',
      nameKey: 'skills.garageExpansion',
      descKey: 'skills.garageExpansionDesc',
      cost: 3,
      emoji: '🚗',
      primaryColor: Color(0xFFE91E63),
      secondaryColor: Color(0xFFF06292),
    ),
    
    // 3. Hızlı Öğrenen - Tüm işlemlerden %25 daha fazla XP
    Skill(
      id: 'fast_learner',
      nameKey: 'skills.fastLearner',
      descKey: 'skills.fastLearnerDesc',
      cost: 1,
      emoji: '⚡',
      primaryColor: Color(0xFF00BCD4),
      secondaryColor: Color(0xFF26C6DA),
    ),
    
    // 4. Pazarlık Gücü - Müzakerede %15 daha fazla indirim
    Skill(
      id: 'negotiation_power',
      nameKey: 'skills.negotiationPower',
      descKey: 'skills.negotiationPowerDesc',
      cost: 2,
      emoji: '💪',
      primaryColor: Color(0xFF4CAF50),
      secondaryColor: Color(0xFF66BB6A),
    ),
    
    // ============================================================================
    // HENÜZ ENTEGRE EDİLMEMİŞ YETENEKLER (YORUM SATIRINDA)
    // ============================================================================
    
    /* ENTEGRASYON BEKLİYOR
    
    // Pazarlık Ustası - Teklif yaparken %10 daha düşük (KISMİ: sadece satın alma)
    Skill(
      id: 'negotiation',
      nameKey: 'skills.negotiation',
      descKey: 'skills.negotiationDesc',
      cost: 2,
      emoji: '💰',
      primaryColor: Color(0xFF4CAF50),
      secondaryColor: Color(0xFF66BB6A),
    ),
    
    // Hızlı Satış - %20 daha hızlı teklif (ENTEGRE DEĞİL)
    Skill(
      id: 'quick_sale',
      nameKey: 'skills.quickSale',
      descKey: 'skills.quickSaleDesc',
      cost: 2,
      emoji: '⚡',
      primaryColor: Color(0xFFFF9800),
      secondaryColor: Color(0xFFFFB74D),
    ),
    
    // Piyasa Analisti - Araç değeri gösterilir (ENTEGRE DEĞİL)
    Skill(
      id: 'market_analyst',
      nameKey: 'skills.marketAnalyst',
      descKey: 'skills.marketAnalystDesc',
      cost: 2,
      emoji: '🔍',
      primaryColor: Color(0xFF2196F3),
      secondaryColor: Color(0xFF42A5F5),
    ),
    
    // Altın Madenci - Görevlerden %50 daha fazla altın (ENTEGRE DEĞİL)
    Skill(
      id: 'gold_miner',
      nameKey: 'skills.goldMiner',
      descKey: 'skills.goldMinerDesc',
      cost: 2,
      emoji: '💎',
      primaryColor: Color(0xFFFFD700),
      secondaryColor: Color(0xFFFFE55C),
    ),
    
    */
  ];

  // ============================================================================
  // YARDIMCI METODLAR
  // ============================================================================

  /// Bir yeteneği ID'sine göre getir
  static Skill? getSkillById(String id) {
    try {
      return skills.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Kullanıcının bir yeteneği açıp açamayacağını kontrol et
  static bool canUnlock(User user, String skillId) {
    final skill = getSkillById(skillId);
    if (skill == null) return false;

    // Zaten açıksa tekrar açamaz
    if (user.unlockedSkills.contains(skillId)) return false;

    // Puanı yetiyor mu?
    if (user.skillPoints < skill.cost) return false;

    return true;
  }

  /// Kullanıcının bir yeteneği olup olmadığını kontrol et
  static bool hasSkill(User user, String skillId) {
    return user.unlockedSkills.contains(skillId);
  }

  // ============================================================================
  // YETENEK ETKİLERİ
  // ============================================================================

  /// Pazarlık Ustası: Teklif yaparken indirim oranı
  static double getNegotiationDiscount(User user) {
    if (hasSkill(user, 'negotiation')) {
      return 0.10; // %10 daha düşük teklif
    }
    return 0.0;
  }

  /// Hızlı Satış: Teklif gelme hızı çarpanı
  static double getOfferSpeedMultiplier(User user) {
    if (hasSkill(user, 'quick_sale')) {
      return 1.20; // %20 daha fazla teklif
    }
    return 1.0;
  }

  /// Piyasa Analisti: Araç değeri gösterilsin mi?
  static bool canSeeMarketValue(User user) {
    return hasSkill(user, 'market_analyst');
  }

  /// İtibar: Gelen tekliflere bonus
  static double getReputationBonus(User user) {
    if (hasSkill(user, 'reputation')) {
      return 0.10; // %10 daha yüksek teklifler
    }
    return 0.0;
  }

  /// Garaj Genişletme: Ekstra kapasite
  static int getGarageLimitBonus(User user) {
    if (hasSkill(user, 'garage_expansion')) {
      return 2; // +2 araç
    }
    return 0;
  }

  /// Altın Madenci: Görev ödülü çarpanı
  static double getGoldMinerMultiplier(User user) {
    if (hasSkill(user, 'gold_miner')) {
      return 1.50; // %50 daha fazla altın
    }
    return 1.0;
  }

  /// Hızlı Öğrenen: XP kazanım çarpanı
  static double getFastLearnerMultiplier(User user) {
    if (hasSkill(user, 'fast_learner')) {
      return 1.25; // %25 daha fazla XP
    }
    return 1.0;
  }

  /// Pazarlık Gücü: Müzakerede indirim bonusu
  static double getNegotiationPowerBonus(User user) {
    if (hasSkill(user, 'negotiation_power')) {
      return 0.15; // %15 daha fazla indirim yapabilir
    }
    return 0.0;
  }

  // ============================================================================
  // BACKWARD COMPATIBILITY (Eski sistem için)
  // ============================================================================

  /// Araç ALIM fiyatı çarpanını hesapla (Eski sistem uyumluluğu)
  /// Şimdilik etkisiz, gelecekte "negotiation" skill'i ile entegre edilebilir
  static double getBuyingMultiplier(User user) {
    // Pazarlık Ustası varsa %10 indirim
    if (hasSkill(user, 'negotiation')) {
      return 0.90; // %10 indirim
    }
    return 1.0;
  }

  /// Araç SATIŞ fiyatı çarpanını hesapla (Eski sistem uyumluluğu)
  /// İtibar skill'i ile entegre
  static double getSellingMultiplier(User user) {
    // İtibar varsa %10 daha yüksek
    if (hasSkill(user, 'reputation')) {
      return 1.10; // %10 daha yüksek
    }
    return 1.0;
  }
}
