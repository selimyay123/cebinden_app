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
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final locale = LocalizationService().currentLanguage;
    final timeAgoStr = timeago.format(
      notification.createdAt,
      locale: locale,
    );

    // Assuming 'title' and 'message' are defined elsewhere or need to be extracted from notification
    // For now, using placeholders or assuming they are available.
    // If not, this part might need further context from the user.
    final String title = notification.title; // Placeholder
    final String message = notification.message; // Placeholder

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
          
          // Navigation logic
          if (notification.data != null) {
            // Check for bulk offer notification
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
            // Check for single offer notification (legacy support or if used elsewhere)
            else if (notification.data!.containsKey('offerId') && notification.data!.containsKey('vehicleId')) {
               // For single offers, we might not have the brand directly in data.
               // We can try to navigate to MyOffersScreen without brand (if supported) or just open the offers tab.
               // Since the requirement specifically mentioned "consolidated offer notification", 
               // and we implemented that, this part is just a fallback.
               // If we don't have brand, we can't deep link to the specific vehicle easily with current MyOffersScreen structure.
               // So we just open MyOffersScreen with incoming tab.
               
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
            color: notification.isRead
                ? Colors.white.withOpacity(0.9)
                : Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? Colors.grey.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İkon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  notification.type.icon,
                  style: const TextStyle(fontSize: 24),
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
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeago.format(notification.createdAt, locale: LocalizationService().currentLanguage),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.newOffer:
        return Colors.blue;
      case NotificationType.offerAccepted:
        return Colors.green;
      case NotificationType.offerRejected:
        return Colors.red;
      case NotificationType.vehicleSold:
        return Colors.purple;
      case NotificationType.priceChange:
        return Colors.orange;
      case NotificationType.system:
        return Colors.grey;
    }
  }
}

