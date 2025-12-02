import 'package:flutter/material.dart';
import '../models/user_model.dart';

class Skill {
  final String id;
  final String name;
  final String description;
  final int cost;
  final IconData icon;
  final String? parentId; // Bu yeteneği açmak için gereken üst yetenek
  final String branch; // 'trader', 'expert', 'tycoon'

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.icon,
    required this.branch,
    this.parentId,
  });
}

class SkillService {
  // ============================================================================
  // YETENEK LİSTESİ (THE SKILL TREE)
  // ============================================================================
  
  static const List<Skill> skills = [
    // --- TÜCCAR (TRADER) DALI ---
    Skill(
      id: 'bargainer_1',
      name: 'Sıkı Pazarlıkçı I',
      description: 'Araç satın alırken %2 indirim sağlar.',
      cost: 1,
      icon: Icons.price_check,
      branch: 'trader',
    ),
    Skill(
      id: 'bargainer_2',
      name: 'Sıkı Pazarlıkçı II',
      description: 'Araç satın alırken %5 indirim sağlar.',
      cost: 2,
      icon: Icons.price_check,
      branch: 'trader',
      parentId: 'bargainer_1',
    ),
    Skill(
      id: 'quick_flip',
      name: 'Hızlı Satış',
      description: 'İlana koyduğun araçlar %20 daha hızlı satılır.',
      cost: 2,
      icon: Icons.flash_on,
      branch: 'trader',
      parentId: 'bargainer_1',
    ),
    Skill(
      id: 'charisma',
      name: 'Ballı Dil',
      description: 'Araç satarken %5 daha yüksek fiyata satarsın.',
      cost: 3,
      icon: Icons.record_voice_over,
      branch: 'trader',
      parentId: 'bargainer_2',
    ),

    // --- UZMAN (EXPERT) DALI ---
    // NOT: Ekspertiz sistemi henüz olmadığı için bu dalı şimdilik boşaltıyoruz veya
    // mevcut özelliklere (XP, İlan) odaklıyoruz.
    
    Skill(
      id: 'market_guru',
      name: 'Piyasa Kurdu',
      description: 'Araç satarken ilanların %50 daha fazla görüntülenir (Daha çok teklif gelir).',
      cost: 1,
      icon: Icons.trending_up,
      branch: 'expert',
    ),
    Skill(
      id: 'xp_booster',
      name: 'Hızlı Öğrenen',
      description: 'Her işlemden %10 daha fazla XP kazanırsın.',
      cost: 2,
      icon: Icons.school,
      branch: 'expert',
      parentId: 'market_guru',
    ),

    // --- PATRON (TYCOON) DALI ---
    Skill(
      id: 'expansion_1',
      name: 'Geniş Garaj I',
      description: '+1 Araç Kapasitesi.',
      cost: 1,
      icon: Icons.garage,
      branch: 'tycoon',
    ),
    Skill(
      id: 'expansion_2',
      name: 'Geniş Garaj II',
      description: '+2 Araç Kapasitesi.',
      cost: 2,
      icon: Icons.garage,
      branch: 'tycoon',
      parentId: 'expansion_1',
    ),
    // Pasif Gelir kaldırıldı (henüz yok)
  ];

  // ============================================================================
  // MANTIK VE HESAPLAMALAR
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

    // Ön koşul (parent) var mı ve açık mı?
    if (skill.parentId != null) {
      if (!user.unlockedSkills.contains(skill.parentId)) return false;
    }

    return true;
  }

  /// Araç ALIM fiyatı çarpanını hesapla (Daha düşük = Daha iyi)
  /// Örn: 0.95 dönerse %5 indirim var demektir.
  static double getBuyingMultiplier(User user) {
    double multiplier = 1.0;

    if (user.unlockedSkills.contains('bargainer_1')) {
      multiplier -= 0.02; // %2 indirim
    }
    if (user.unlockedSkills.contains('bargainer_2')) {
      multiplier -= 0.05; // %5 indirim (Toplam %7 olabilir veya kümülatif)
    }
    // Basit toplama mantığı: %2 + %5 = %7 indirim -> 0.93
    
    return multiplier.clamp(0.1, 1.0); // En az %10 fiyatına alınabilir, bedava olamaz
  }

  /// Araç SATIŞ fiyatı çarpanını hesapla (Daha yüksek = Daha iyi)
  /// Örn: 1.05 dönerse %5 daha pahalıya satılır.
  static double getSellingMultiplier(User user) {
    double multiplier = 1.0;

    if (user.unlockedSkills.contains('charisma')) {
      multiplier += 0.05; // %5 daha pahalı
    }

    return multiplier;
  }
  
  /// Garaj limiti bonusunu hesapla
  static int getGarageLimitBonus(User user) {
    int bonus = 0;
    
    if (user.unlockedSkills.contains('expansion_1')) {
      bonus += 1;
    }
    if (user.unlockedSkills.contains('expansion_2')) {
      bonus += 2;
    }
    
    return bonus;
  }
  
  /// Satış süresi çarpanı (Daha düşük = Daha hızlı)
  static double getSalesSpeedMultiplier(User user) {
    double multiplier = 1.0;
    
    if (user.unlockedSkills.contains('quick_flip')) {
      multiplier *= 0.8; // %20 daha hızlı
    }
    
    return multiplier;
  }
}
