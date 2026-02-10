import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';
import '../services/activity_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../widgets/modern_alert_dialog.dart';
import '../widgets/custom_snackbar.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'dart:async'; // For StreamSubscription
import '../services/staff_service.dart'; // Import StaffService

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ActivityService _activityService = ActivityService();
  final DatabaseHelper _db = DatabaseHelper();
  final StaffService _staffService = StaffService(); // Initialize StaffService
  StreamSubscription? _staffEventSubscription;

  User? _currentUser;
  List<Activity> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupStaffEventListener(); // Start listening

    // Türkçe timeago mesajlarını ekle
    timeago.setLocaleMessages('tr', timeago.TrMessages());
  }

  @override
  void dispose() {
    _staffEventSubscription?.cancel(); // Cancel subscription to avoid leaks
    super.dispose();
  }

  void _setupStaffEventListener() {
    _staffEventSubscription = _staffService.eventStream.listen((event) {
      // If a staff action occurred (sale or purchase), reload data
      if (event.startsWith('staff_action')) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    // Only show loading indicator if it's the first load or explicit reload logic requires it.
    // For auto-refresh, we might want to be more subtle, but sticking to existing pattern for now.
    // However, fast updates with full loading spinner might be annoying.
    // Let's keep it simple: just call existing _loadData which sets isLoading=true.
    // Improve UI later if needed.
    if (!mounted) return;

    // setState(() => _isLoading = true); // _loadData already does this

    try {
      final userMap = await _db.getCurrentUser();
      if (userMap != null) {
        _currentUser = User.fromJson(userMap);
        _activities = await _activityService.getUserActivities(
          _currentUser!.id,
        );
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAll() async {
    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'activity.clearAll'.tr(),
        content: Text('activity.clearAllConfirm'.tr()),
        buttonText: 'common.delete'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.delete_forever,
        isDestructive: true,
      ),
    );

    if (confirmed == true && _currentUser != null) {
      await _activityService.clearAllActivities(_currentUser!.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          CustomSnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text('activity.cleared'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ownsGallery = _currentUser?.ownsGallery ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('activity.title'.tr()),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
          bottom: ownsGallery
              ? TabBar(
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Colors.black,
                  tabs: [
                    Tab(text: 'activity.tab_general'.tr()),
                    Tab(text: 'activity.tab_staff'.tr()),
                  ],
                )
              : null,
          actions: [
            if (_activities.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'activity.clearAll'.tr(),
                onPressed: _clearAll,
              ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/general_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ownsGallery
                ? TabBarView(
                    children: [
                      _getGeneralActivities().isEmpty
                          ? _buildEmptyState()
                          : _buildActivitiesList(_getGeneralActivities()),
                      _getStaffActivities().isEmpty
                          ? _buildEmptyState()
                          : _buildStaffActivitiesList(),
                    ],
                  )
                : (_activities.isEmpty
                      ? _buildEmptyState()
                      : _buildActivitiesList(_activities)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 120, color: Colors.black),
          const SizedBox(height: 24),
          Text(
            'activity.noActivities'.tr(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'activity.noActivitiesDesc'.tr(),
              style: TextStyle(fontSize: 16, color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesList(List<Activity> activities) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  Widget _buildActivityCard(Activity activity) {
    final locale = LocalizationService().currentLanguage;
    final timeAgoStr = timeago.format(activity.date, locale: locale);

    // Dynamic Localization Logic
    String title = activity.title;
    if (activity.titleKey != null && activity.titleKey!.isNotEmpty) {
      String translatedTitle;
      if (activity.titleParams != null && activity.titleParams!.isNotEmpty) {
        final Map<String, String> stringParams = activity.titleParams!.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        translatedTitle = activity.titleKey!.trParams(stringParams);
      } else {
        translatedTitle = activity.titleKey!.tr();
      }

      // Fallback: Eğer çeviri yapılamadıysa (key döndüyse) static title'ı koru
      if (translatedTitle != activity.titleKey) {
        title = translatedTitle;
      }
    }

    String description = activity.description;
    if (activity.descriptionKey != null &&
        activity.descriptionKey!.isNotEmpty) {
      String translatedDesc;
      if (activity.descriptionParams != null &&
          activity.descriptionParams!.isNotEmpty) {
        final Map<String, String> stringParams = activity.descriptionParams!
            .map((key, value) => MapEntry(key, value.toString()));
        translatedDesc = activity.descriptionKey!.trParams(stringParams);
      } else {
        translatedDesc = activity.descriptionKey!.tr();
      }

      // Fallback: Çeviri yapılamadıysa static description koru
      if (translatedDesc != activity.descriptionKey) {
        description = translatedDesc;
      }

      // Level up için hack (static text'te SP varsa ve biz çevirdiysek korumak isteyebiliriz ama
      // şimdilik parametrik çeviriye güveniyoruz)
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.85), // Purple background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İkon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getActivityIcon(activity.type),
                color: Colors.white, // White icon
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // White title
                          ),
                        ),
                      ),
                      if (activity.amount != null) _buildAmountText(activity),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(
                        alpha: 0.9,
                      ), // White description
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeAgoStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(
                        alpha: 0.6,
                      ), // Dim white time
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.purchase:
        return Icons.shopping_cart;
      case ActivityType.sale:
        return Icons.sell;
      case ActivityType.rental:
        return Icons.key;
      case ActivityType.levelUp:
        return Icons.star;
      case ActivityType.taxi:
        return Icons.local_taxi;
      case ActivityType.dailyLogin:
        return Icons.calendar_today;
      case ActivityType.expense:
        return Icons.money_off;
      case ActivityType.income:
        return Icons.attach_money;
      case ActivityType.staffPurchase:
        return Icons.shopping_bag;
      case ActivityType.staffSale:
        return Icons.store;
    }
  }

  Widget _buildAmountText(Activity activity) {
    final isGold = activity.type == ActivityType.dailyLogin;
    final amount = activity.amount!;
    final isPositive = amount > 0;
    final prefix = isPositive ? '+' : '';

    String formattedAmount;
    String currency;
    Color color;

    if (isGold) {
      // Gold için ondalıklı gösterim (örn: 0.1, 0.2)
      formattedAmount = amount
          .toStringAsFixed(1)
          .replaceAll(RegExp(r'\.0$'), '');
      currency = 'Gold';
      color = Colors.amber[700]!;
    } else {
      // TL için tamsayı gösterim
      formattedAmount = _formatCurrency(amount);
      currency = 'TL';
      color = isPositive ? Colors.green : Colors.red;
    }

    return Text(
      '$prefix$formattedAmount $currency',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
    );
  }

  String _formatCurrency(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  List<Activity> _getGeneralActivities() {
    return _activities
        .where(
          (a) =>
              a.type != ActivityType.staffPurchase &&
              a.type != ActivityType.staffSale,
        )
        .toList();
  }

  List<Activity> _getStaffActivities() {
    return _activities
        .where(
          (a) =>
              a.type == ActivityType.staffPurchase ||
              a.type == ActivityType.staffSale,
        )
        .toList();
  }

  Widget _buildStaffActivitiesList() {
    final staffActivities = _getStaffActivities();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: staffActivities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final activity = staffActivities[index];
        return _buildStaffActivityCard(activity);
      },
    );
  }

  Widget _buildStaffActivityCard(Activity activity) {
    final locale = LocalizationService().currentLanguage;
    final timeAgoStr = timeago.format(activity.date, locale: locale);
    final isSale = activity.type == ActivityType.staffSale;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.9,
        ), // Lighter background for staff
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            isSale ? Icons.store : Icons.shopping_bag,
            color: isSale ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (activity.description.isNotEmpty)
                  Text(
                    activity.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSale ? Colors.green[700] : Colors.black54,
                      fontWeight: isSale ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildAmountText(
                activity,
              ), // Reuse amount text but careful with color
              Text(
                timeAgoStr,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
