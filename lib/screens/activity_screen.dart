import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';
import '../services/activity_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'main_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ActivityService _activityService = ActivityService();
  final DatabaseHelper _db = DatabaseHelper();
  
  User? _currentUser;
  List<Activity> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Türkçe timeago mesajlarını ekle
    timeago.setLocaleMessages('tr', timeago.TrMessages());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final userMap = await _db.getCurrentUser();
      if (userMap != null) {
        _currentUser = User.fromJson(userMap);
        _activities = await _activityService.getUserActivities(_currentUser!.id);
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('activity.clearAll'.tr()),
        content: Text('activity.clearAllConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && _currentUser != null) {
      await _activityService.clearAllActivities(_currentUser!.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('activity.cleared'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('activity.title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
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
              : _activities.isEmpty
                  ? _buildEmptyState()
                  : _buildActivitiesList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 120,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'activity.noActivities'.tr(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'activity.noActivitiesDesc'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final activity = _activities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  Widget _buildActivityCard(Activity activity) {
    final locale = LocalizationService().currentLanguage;
    final timeAgoStr = timeago.format(
      activity.date,
      locale: locale,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.85), // Purple background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                color: Colors.white.withOpacity(0.1),
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
                          activity.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // White title
                          ),
                        ),
                      ),
                      if (activity.amount != null)
                        _buildAmountText(activity),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9), // White description
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeAgoStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6), // Dim white time
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
      formattedAmount = amount.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
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
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
