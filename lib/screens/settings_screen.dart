import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/settings_helper.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';
import 'profile_info_screen.dart';
import 'change_password_screen.dart';
import 'about_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  late SettingsHelper _settingsHelper;
  User? _currentUser;
  bool _isLoading = true;

  // Settings states
  bool _darkMode = false;
  String _selectedCurrency = 'TL';
  bool _notificationNewListings = true;
  bool _notificationPriceDrops = true;
  bool _notificationOffers = true;
  bool _notificationSystem = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _settingsHelper = await SettingsHelper.getInstance();
      _currentUser = await _authService.getCurrentUser();

      if (_currentUser != null) {
        setState(() {
          _selectedCurrency = _currentUser!.currency;
        });
      }

      final darkMode = await _settingsHelper.getDarkMode();
      final newListings = await _settingsHelper.getNotificationNewListings();
      final priceDrops = await _settingsHelper.getNotificationPriceDrops();
      final offers = await _settingsHelper.getNotificationOffers();
      final system = await _settingsHelper.getNotificationSystem();

      setState(() {
        _darkMode = darkMode;
        _notificationNewListings = newListings;
        _notificationPriceDrops = priceDrops;
        _notificationOffers = offers;
        _notificationSystem = system;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    // Şimdilik sadece ayarı kaydet, theme değişimi yakında eklenecek
    setState(() => _darkMode = value);
    await _settingsHelper.setDarkMode(value);
    
    // Kullanıcıya bilgi ver
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Karanlık mod özelliği yakında aktif olacak'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _updateCurrency(String? currency) async {
    if (currency == null || _currentUser == null) return;

    final success = await _authService.updateUserInfo(
      userId: _currentUser!.id,
      currency: currency,
    );

    if (success) {
      setState(() => _selectedCurrency = currency);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para birimi güncellendi')),
        );
      }
    }
  }

  Future<void> _toggleNotification(String type, bool value) async {
    switch (type) {
      case 'newListings':
        setState(() => _notificationNewListings = value);
        await _settingsHelper.setNotificationNewListings(value);
        break;
      case 'priceDrops':
        setState(() => _notificationPriceDrops = value);
        await _settingsHelper.setNotificationPriceDrops(value);
        break;
      case 'offers':
        setState(() => _notificationOffers = value);
        await _settingsHelper.setNotificationOffers(value);
        break;
      case 'system':
        setState(() => _notificationSystem = value);
        await _settingsHelper.setNotificationSystem(value);
        break;
    }
  }

  Future<void> _clearDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Veritabanını Temizle'),
        content: const Text(
          'Tüm kullanıcılar ve veriler silinecek. Bu işlem geri alınamaz. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper().clearDatabase();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Hesabınız kalıcı olarak silinecek. Bu işlem geri alınamaz. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _authService.deleteAccount(_currentUser!.id);
      if (success && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Profil Bölümü
          _buildSection(
            title: 'Profil',
            children: [
              _buildListTile(
                icon: Icons.person_outline,
                title: 'Profil Bilgileri',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileInfoScreen(user: _currentUser!),
                    ),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.lock_outline,
                title: 'Şifre Değiştir',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangePasswordScreen(userId: _currentUser!.id),
                    ),
                  );
                },
              ),
            ],
          ),

          // Görünüm Ayarları
          _buildSection(
            title: 'Görünüm',
            children: [
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Karanlık Mod',
                subtitle: 'Gece modunu aktifleştir',
                value: _darkMode,
                onChanged: _toggleDarkMode,
              ),
              _buildListTile(
                icon: Icons.account_balance_wallet,
                title: 'Para Birimi',
                trailing: DropdownButton<String>(
                  value: _selectedCurrency,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'TL', child: Text('TL')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  ],
                  onChanged: _updateCurrency,
                ),
              ),
            ],
          ),

          // Bildirim Ayarları
          _buildSection(
            title: 'Bildirimler',
            children: [
              _buildSwitchTile(
                icon: Icons.new_releases_outlined,
                title: 'Yeni İlan Bildirimleri',
                value: _notificationNewListings,
                onChanged: (value) => _toggleNotification('newListings', value),
              ),
              _buildSwitchTile(
                icon: Icons.trending_down,
                title: 'Fiyat Düşüş Bildirimleri',
                value: _notificationPriceDrops,
                onChanged: (value) => _toggleNotification('priceDrops', value),
              ),
              _buildSwitchTile(
                icon: Icons.local_offer_outlined,
                title: 'Teklif Bildirimleri',
                value: _notificationOffers,
                onChanged: (value) => _toggleNotification('offers', value),
              ),
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Sistem Bildirimleri',
                value: _notificationSystem,
                onChanged: (value) => _toggleNotification('system', value),
              ),
            ],
          ),

          // Uygulama Bilgisi
          _buildSection(
            title: 'Uygulama',
            children: [
              _buildListTile(
                icon: Icons.info_outline,
                title: 'Hakkında',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  );
                },
              ),
            ],
          ),

          // Debug (Geliştirici Ayarları)
          _buildSection(
            title: 'Geliştirici',
            children: [
              _buildListTile(
                icon: Icons.delete_sweep,
                title: 'Veritabanını Temizle',
                subtitle: 'Tüm kullanıcılar ve veriler silinir',
                textColor: Colors.orange,
                onTap: _clearDatabase,
              ),
            ],
          ),

          // Hesap İşlemleri
          _buildSection(
            title: 'Hesap',
            children: [
              _buildListTile(
                icon: Icons.delete_forever,
                title: 'Hesabı Sil',
                subtitle: 'Hesabınız kalıcı olarak silinir',
                textColor: Colors.red,
                onTap: _deleteAccount,
              ),
              _buildListTile(
                icon: Icons.logout,
                title: 'Çıkış Yap',
                textColor: Colors.red,
                onTap: _logout,
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.deepPurple),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.deepPurple),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepPurple,
    );
  }
}

