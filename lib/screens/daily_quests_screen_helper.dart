  String _getLocalizedDescription(DailyQuest quest) {
    // Yeni sistem: Key ise çevir
    if (quest.description.startsWith('quests.')) {
      return quest.description.trParams({
        'count': quest.targetCount.toString(),
        'amount': _formatCurrency(quest.targetCount.toDouble()),
      });
    }

    // Eski sistem: Hardcoded stringleri yakala ve çevir
    if (quest.description.contains('araç satın al')) {
      return 'quests.descriptions.buyVehicle'.trParams({'count': quest.targetCount.toString()});
    }
    if (quest.description.contains('araç sat')) {
      return 'quests.descriptions.sellVehicle'.trParams({'count': quest.targetCount.toString()});
    }
    if (quest.description.contains('teklif gönder')) {
      return 'quests.descriptions.makeOffer'.trParams({'count': quest.targetCount.toString()});
    }
    if (quest.description.contains('kâr et')) {
      return 'quests.descriptions.earnProfit'.trParams({'amount': _formatCurrency(quest.targetCount.toDouble())});
    }

    // Hiçbiri değilse olduğu gibi göster
    return quest.description;
  }
