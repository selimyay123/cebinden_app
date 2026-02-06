class QuickChatData {
  static const List<Map<String, dynamic>> categories = [
    {
      'id': 'greeting',
      'icon': '👋',
      'labelKey': 'social.chat.category.greeting',
      'messages': [
        'social.chat.msg.hello',
        'social.chat.msg.how_are_you',
        'social.chat.msg.good_morning',
        'social.chat.msg.good_evening',
      ],
    },
    {
      'id': 'business',
      'icon': '🤝',
      'labelKey': 'social.chat.category.business',
      'messages': [
        'social.chat.msg.good_work',
        'social.chat.msg.business_is_good',
        'social.chat.msg.hard_market',
        'social.chat.msg.sold_car',
      ],
    },
    {
      'id': 'cars',
      'icon': '🏎️',
      'labelKey': 'social.chat.category.cars',
      'messages': [
        'social.chat.msg.nice_car',
        'social.chat.msg.lets_race',
        'social.chat.msg.garage_looks_great',
        'social.chat.msg.dream_car',
      ],
    },
    {
      'id': 'reactions',
      'icon': '😎',
      'labelKey': 'social.chat.category.reactions',
      'messages': [
        'social.chat.msg.congrats',
        'social.chat.msg.wow',
        'social.chat.msg.thanks',
        'social.chat.msg.good_luck',
        'social.chat.msg.thumbs_up',
        'social.chat.msg.fire',
      ],
    },
  ];

  static List<String> getMessagesByCategory(String categoryId) {
    final category = categories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => {'messages': <String>[]},
    );
    return category['messages'] as List<String>;
  }
}
