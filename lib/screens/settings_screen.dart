import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/settings_helper.dart';
import '../services/database_helper.dart';
import '../services/offer_service.dart';
import '../services/localization_service.dart';
import '../services/game_time_service.dart';
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
  final OfferService _offerService = OfferService();
  final LocalizationService _localizationService = LocalizationService();
  final GameTimeService _gameTimeService = GameTimeService();
  late SettingsHelper _settingsHelper;
  User? _currentUser;
  bool _isLoading = true;

  // Settings states
  bool _darkMode = false;
  String _selectedLanguage = 'tr'; // Varsayılan Türkçe
  String _selectedCurrency = 'TL';
  bool _notificationNewListings = true;
  bool _notificationPriceDrops = true;
  bool _notificationOffers = true;
  bool _notificationSystem = true;
  int _gameDayDuration = 10; // Dakika cinsinden

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
      final gameDayDuration = await SettingsHelper.getGameDayDuration();

      setState(() {
        _darkMode = darkMode;
        _selectedLanguage = _localizationService.currentLanguage; // Mevcut dili yükle
        _notificationNewListings = newListings;
        _notificationPriceDrops = priceDrops;
        _notificationOffers = offers;
        _notificationSystem = system;
        _gameDayDuration = gameDayDuration;
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
  }
  
  Future<void> _changeGameDayDuration(int? minutes) async {
    if (minutes == null || minutes == _gameDayDuration) return;
    
    setState(() => _gameDayDuration = minutes);
    await _gameTimeService.setGameDayDuration(minutes);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Oyun günü süresi $minutes dakika olarak ayarlandı'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _changeLanguage(String? languageCode) async {
    if (languageCode == null || languageCode == _selectedLanguage) return;

    // Dili değiştir
    bool success = await _localizationService.changeLanguage(languageCode);

    if (success && mounted) {
      setState(() {
        _selectedLanguage = languageCode;
      });

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.languageChanged'.tr()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // NOT: MaterialApp otomatik rebuild olacak, ekstra setState gerekmez!
    }
    
    // Kullanıcıya bilgi ver
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.darkModeComingSoon'.tr()),
          duration: const Duration(seconds: 2),
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
          SnackBar(content: Text('settings.currencyUpdated'.tr())),
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

  Future<void> _generateTestOffers() async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Teklifler oluşturuluyor...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    try {
      // AI tekliflerini oluştur
      int offersCreated = await _offerService.generateDailyOffers();

      if (mounted) {
        Navigator.pop(context); // Loading'i kapat

        if (offersCreated == 0) {
          // Hiç teklif oluşturulmadıysa açıklayıcı mesaj göster
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('ℹ️ ${'common.info'.tr()}'),
              content: Text('settings.noListingsForOffers'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('settings.ok'.tr()),
                ),
              ],
            ),
          );
        } else {
          // Sonuç göster
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('✅ ${'settings.success'.tr()}'),
              content: Text('$offersCreated ${'settings.offersCreatedSuccess'.tr()}\n\n${'settings.checkOffersSection'.tr()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('settings.ok'.tr()),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Loading'i kapat

        // Hata göster
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('❌ ${'settings.error'.tr()}'),
            content: Text('${'settings.offersCreatedError'.tr()}:\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('settings.ok'.tr()),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _clearDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.clearDatabase'.tr()),
        content: Text('settings.clearDatabaseConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('settings.clearDatabase'.tr()),
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
        title: Text('settings.deleteAccount'.tr()),
        content: Text('settings.deleteAccountConfirm'.tr()),
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
        title: Text('auth.logout'.tr()),
        content: Text('auth.logoutConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('auth.logout'.tr()),
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
    // ValueListenableBuilder ile dil değişikliklerini dinle
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('settings.title'.tr()),
            elevation: 0,
          ),
      body: ListView(
        children: [
          // TEST BUTONU - GEÇİCİ
          Container(
            margin: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_currentUser != null) {
                  final db = DatabaseHelper();
                  await db.updateUser(_currentUser!.id, {
                    'gold': _currentUser!.gold + 100.0,
                  });
                  
                  // Kullanıcıyı yeniden yükle
                  await _loadSettings();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Test: 100 Altın eklendi!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.stars),
              label: const Text('TEST: 100 Altın Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          // Profil Bölümü
          _buildSection(
            title: 'settings.profile'.tr(),
            children: [
              _buildListTile(
                icon: Icons.person_outline,
                title: 'settings.profileInfo'.tr(),
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
                title: 'settings.changePassword'.tr(),
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
            title: 'settings.appearance'.tr(),
            children: [
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'settings.darkMode'.tr(),
                subtitle: 'settings.darkModeDesc'.tr(),
                value: _darkMode,
                onChanged: _toggleDarkMode,
              ),
              _buildListTile(
                icon: Icons.language,
                title: 'settings.languageFull'.tr(),
                trailing: DropdownButton<String>(
                  value: _selectedLanguage,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: _changeLanguage,
                ),
              ),
              _buildListTile(
                icon: Icons.account_balance_wallet,
                title: 'settings.currency'.tr(),
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

          // Oyun Ayarları
          _buildSection(
            title: 'Oyun Ayarları',
            children: [
              _buildListTile(
                icon: Icons.access_time,
                title: 'Oyun Günü Süresi',
                subtitle: '1 oyun günü = $_gameDayDuration dakika (gerçek zaman)',
                trailing: DropdownButton<int>(
                  value: _gameDayDuration,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 dk')),
                    DropdownMenuItem(value: 10, child: Text('10 dk')),
                    DropdownMenuItem(value: 15, child: Text('15 dk')),
                    DropdownMenuItem(value: 20, child: Text('20 dk')),
                    DropdownMenuItem(value: 30, child: Text('30 dk')),
                  ],
                  onChanged: _changeGameDayDuration,
                ),
              ),
              _buildListTile(
                icon: Icons.calendar_today,
                title: 'Mevcut Oyun Zamanı',
                subtitle: _gameTimeService.getFormattedGameTime(),
                trailing: const Icon(Icons.info_outline, size: 20),
              ),
            ],
          ),

          // Bildirim Ayarları
          _buildSection(
            title: 'settings.notifications'.tr(),
            children: [
              _buildSwitchTile(
                icon: Icons.new_releases_outlined,
                title: 'settings.newListings'.tr(),
                value: _notificationNewListings,
                onChanged: (value) => _toggleNotification('newListings', value),
              ),
              _buildSwitchTile(
                icon: Icons.trending_down,
                title: 'settings.priceDrops'.tr(),
                value: _notificationPriceDrops,
                onChanged: (value) => _toggleNotification('priceDrops', value),
              ),
              _buildSwitchTile(
                icon: Icons.local_offer_outlined,
                title: 'settings.offers'.tr(),
                value: _notificationOffers,
                onChanged: (value) => _toggleNotification('offers', value),
              ),
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'settings.system'.tr(),
                value: _notificationSystem,
                onChanged: (value) => _toggleNotification('system', value),
              ),
            ],
          ),

          // Uygulama Bilgisi
          _buildSection(
            title: 'settings.appInfo'.tr(),
            children: [
              _buildListTile(
                icon: Icons.info_outline,
                title: 'settings.about'.tr(),
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
            title: 'settings.developer'.tr(),
            children: [
              _buildListTile(
                icon: Icons.auto_awesome,
                title: 'settings.generateOffers'.tr(),
                subtitle: 'settings.generateOffersDesc'.tr(),
                textColor: Colors.blue,
                onTap: _generateTestOffers,
              ),
              _buildListTile(
                icon: Icons.delete_sweep,
                title: 'settings.clearDatabase'.tr(),
                subtitle: 'settings.clearDatabaseDesc'.tr(),
                textColor: Colors.orange,
                onTap: _clearDatabase,
              ),
            ],
          ),

          // Hesap İşlemleri
          _buildSection(
            title: 'settings.account'.tr(),
            children: [
              _buildListTile(
                icon: Icons.delete_forever,
                title: 'settings.deleteAccount'.tr(),
                subtitle: 'settings.deleteAccountDesc'.tr(),
                textColor: Colors.red,
                onTap: _deleteAccount,
              ),
              _buildListTile(
                icon: Icons.logout,
                title: 'settings.logoutButton'.tr(),
                textColor: Colors.red,
                onTap: _logout,
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
      },
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

