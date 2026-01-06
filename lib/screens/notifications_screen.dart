import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../widgets/modern_alert_dialog.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'main_screen.dart';
import 'my_offers_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final DatabaseHelper _db = DatabaseHelper();
  
  User? _currentUser;
  List<AppNotification> _notifications = [];
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
        _notifications = await _notificationService.getUserNotifications(_currentUser!.id);
      }
    } catch (e) {
      
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
      await _loadData();
    }
  }

  Future<void> _markAllAsRead() async {
    if (_currentUser != null) {
      await _notificationService.markAllAsRead(_currentUser!.id);
      await _loadData();
    }
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    await _notificationService.deleteNotification(notification.id);
    await _loadData();
  }

  Future<void> _deleteAll() async {
    // Onay dialogu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'notifications.deleteAll'.tr(),
        content: Text('notifications.deleteAllConfirm'.tr(), style: const TextStyle(color: Colors.white70)),
        buttonText: 'common.delete'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.delete_sweep,
        iconColor: Colors.redAccent,
      ),
    );

    if (confirm == true && _currentUser != null) {
      await _notificationService.deleteAllNotifications(_currentUser!.id);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('notifications.title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [

          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'notifications.markAllRead'.tr(),
              onPressed: _markAllAsRead,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'notifications.deleteAll'.tr(),
              onPressed: _deleteAll,
            ),
          ],
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
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : _buildNotificationsList(),
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
            Icons.notifications_none_outlined,
            size: 120,
            color: Colors.black,
          ),
          const SizedBox(height: 24),
          Text(
            'notifications.noNotifications'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'notifications.noNotificationsDesc'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final locale = LocalizationService().currentLanguage;

    // final String title = notification.title; // Title removed as per request
    final String message = notification.message;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notification),
      child: InkWell(
        onTap: () async {
          await _markAsRead(notification);
          
          if (notification.data != null) {
            if (notification.data!.containsKey('vehicleId') && notification.data!.containsKey('brand')) {
               final vehicleId = notification.data!['vehicleId'];
               final brand = notification.data!['brand'];
               
               Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyOffersScreen(
                      selectedBrand: brand,
                      selectedVehicleId: vehicleId,
                      isIncoming: true,
                    ),
                  ),
                );
            }
            else if (notification.data!.containsKey('offerId') && notification.data!.containsKey('vehicleId')) {
               Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyOffersScreen(
                      isIncoming: true,
                      initialTab: 0,
                    ),
                  ),
                );
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
          // margin: const EdgeInsets.only(bottom: 12), // Margin removed
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95), // White message
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!notification.isRead)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.amber, // Amber dot for visibility
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                timeago.format(notification.createdAt, locale: LocalizationService().currentLanguage),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6), // Dim white time
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}

