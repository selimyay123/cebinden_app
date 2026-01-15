import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/settings_helper.dart';
import '../services/localization_service.dart';
import '../services/game_time_service.dart';
import '../models/user_model.dart';
import 'profile_info_screen.dart';
import 'change_password_screen.dart';
import 'change_username_screen.dart';
import 'about_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'statistics_screen.dart';
import 'admin_panel_screen.dart';
import '../services/market_refresh_service.dart';
import '../services/database_helper.dart';
import '../widgets/user_profile_avatar.dart';
import '../widgets/modern_alert_dialog.dart';
import '../services/xp_service.dart';
import '../services/ad_service.dart';
import '../widgets/level_up_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final bool highlightProfilePicture;

  const SettingsScreen({
    super.key,
    this.highlightProfilePicture = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with LocalizationMixin, SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final LocalizationService _localizationService = LocalizationService();
  final GameTimeService _gameTimeService = GameTimeService();
  late SettingsHelper _settingsHelper;
  User? _currentUser;
  bool _isLoading = true;
  
  // Animation for highlighting
  late AnimationController _highlightController;
  late Animation<Color?> _highlightAnimation;

  // Settings states
  bool _darkMode = false;
  String _selectedLanguage = 'tr'; // Varsayılan Türkçe
  String _selectedCurrency = 'TL';
  bool _notificationNewListings = true;
  bool _notificationPriceDrops = true;
  bool _notificationOffers = true;
  bool _notificationSystem = true;
  int _gameDayDuration = 5; // Dakika cinsinden

  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _highlightAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.deepPurple.withOpacity(0.3),
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    ));

    if (widget.highlightProfilePicture) {
      _highlightController.repeat(reverse: true);
      // Stop animation after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _highlightController.stop();
          _highlightController.reset();
        }
      });
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
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
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          content: Text('settings.gameDayDurationUpdated'.trParams({'minutes': minutes.toString()})),
          backgroundColor: Colors.green.withOpacity(0.8),
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
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          content: Text('settings.languageChanged'.tr()),
          backgroundColor: Colors.green.withOpacity(0.8),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // NOT: MaterialApp otomatik rebuild olacak, ekstra setState gerekmez!
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
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            content: Text('settings.currencyUpdated'.tr()),
            backgroundColor: Colors.grey.withOpacity(0.8),
          ),
        );
      }
    }
  }



  void _showProfilePictureDialog() {
    final List<String> profileImages = [
      'assets/pp/man1.png',
      'assets/pp/man2.png',
      'assets/pp/man3.png',
      'assets/pp/women1.png',
      'assets/pp/women2.png',
      'assets/pp/women3.png',
    ];

    // Add purchased animated PPs
    if (_currentUser != null) {
      final animationMap = {
        'MEMEWE': 'assets/animations/pp/MEMEWE.json',
        'Money': 'assets/animations/pp/Money.json',
        'VK': 'assets/animations/vk.json',
        'PEPE': 'assets/animations/pp/PEPE.json',
        'CoolEmoji': 'assets/animations/pp/Cool emoji.json',
        'PepeMusic': 'assets/animations/pp/Pepe Sticker Music.json',
        'NyanCat': 'assets/animations/pp/The Nyan Cat.json',
      };

      for (final ppName in _currentUser!.purchasedAnimatedPPs) {
        if (animationMap.containsKey(ppName)) {
          profileImages.add(animationMap[ppName]!);
        }
      }
    }

    String? selectedImage = _currentUser?.profileImageUrl;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return ModernAlertDialog(
            title: 'settings.selectProfilePicture'.tr(),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: profileImages.length,
                itemBuilder: (context, index) {
                  final imagePath = profileImages[index];
                  final isSelected = selectedImage == imagePath;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedImage = imagePath;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected 
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                      ),
                      child: UserProfileAvatar(
                        imageUrl: imagePath,
                        radius: 30,
                      ),
                    ),
                  );
                },
              ),
            ),
            buttonText: 'common.save'.tr(),
            onPressed: selectedImage != null && selectedImage != _currentUser?.profileImageUrl
                ? () {
                    Navigator.pop(context);
                    _updateProfilePicture(selectedImage!);
                  }
                : () {}, // Disabled state handled visually or ignored? ModernAlertDialog button is always enabled currently. 
                         // TODO: Maybe add enabled state to ModernAlertDialog button? For now, just no-op.
            secondaryButtonText: 'common.cancel'.tr(),
            onSecondaryPressed: () => Navigator.pop(context),
          );
        }
      ),
    );
  }

  Future<void> _updateProfilePicture(String imagePath) async {
    if (_currentUser == null) return;

    final success = await _authService.updateUserInfo(
      userId: _currentUser!.id,
      profileImageUrl: imagePath,
    );

    if (success) {
      await _loadSettings(); // Reload user to update UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.profilePictureUpdated'.tr()),
            backgroundColor: Colors.green.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error'.tr()),
            backgroundColor: Colors.red.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
          ),
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

  /// Seviye atlama dialogu göster
  Future<void> _showLevelUpDialog(XPGainResult result) async {
    if (!mounted || result.rewards == null) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(
        reward: result.rewards!,
      ),
    );

    // Dialog kapandıktan      // Reklam göster (eğer hazırsa ve kullanıcıda reklam kaldırma yoksa)
      if (mounted) {
        AdService().showInterstitialAd(force: true, hasNoAds: _currentUser?.hasNoAds ?? false);
      }
  }

  Future<void> _deleteAccount() async {
    if (_currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'settings.deleteAccount'.tr(),
        content: Text(
          'settings.deleteAccountConfirm'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        buttonText: 'common.delete'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.delete_forever,
        iconColor: Colors.redAccent,
      ),
    );

    if (confirm == true) {
      final success = await _authService.deleteAccount(_currentUser!.id);
      if (success && mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'auth.logout'.tr(),
        content: Text(
          'auth.logoutConfirm'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        buttonText: 'auth.logout'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.logout,
        iconColor: Colors.redAccent,
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
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
            actions: [

            ],
            elevation: 0,
          ),
      body: ListView(
        children: [
          // Geliştirici Bonusu (Sadece Admin)
          if (_currentUser != null && _authService.isUserAdmin(_currentUser!))
            Container(
              margin: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final db = DatabaseHelper();
                  final success = await db.updateUser(_currentUser!.id, {
                    'gold': _currentUser!.gold + 100.0,
                    'skillPoints': _currentUser!.skillPoints + 1000,
                  });
                  
                  if (success) {
                    await _loadSettings();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('settings.devBonusSuccess'.tr()),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.auto_awesome),
                label: Text('settings.devBonus'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

              AnimatedBuilder(
                animation: _highlightAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: _highlightAnimation.value,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildListTile(
                      icon: Icons.image,
                      title: 'settings.changeProfilePicture'.tr(),
                      onTap: _showProfilePictureDialog,
                    ),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.edit,
                title: 'changeUsername.title'.tr(),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeUsernameScreen(
                        userId: _currentUser!.id,
                        currentUsername: _currentUser!.username,
                      ),
                    ),
                  );
                  
                  // Eğer kullanıcı adı değiştiyse ayarları yeniden yükle
                  if (result == true) {
                    _loadSettings();
                  }
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
              // KARANKLIK MOD - Geçici olarak devre dışı
              // _buildSwitchTile(
              //   icon: Icons.dark_mode_outlined,
              //   title: 'settings.darkMode'.tr(),
              //   subtitle: 'settings.darkModeDesc'.tr(),
              //   value: _darkMode,
              //   onChanged: _toggleDarkMode,
              // ),
              _buildListTile(
                icon: Icons.language,
                title: 'settings.languageFull'.tr(),
                trailing: DropdownButton<String>(
                  value: _selectedLanguage,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: 'tr', child: Text('settings.turkish'.tr())),
                    DropdownMenuItem(value: 'en', child: Text('settings.english'.tr())),
                  ],
                  onChanged: _changeLanguage,
                ),
              ),
              // PARA BİRİMİ - Geçici olarak devre dışı (sadece TL)
              // _buildListTile(
              //   icon: Icons.account_balance_wallet,
              //   title: 'settings.currency'.tr(),
              //   trailing: DropdownButton<String>(
              //     value: _selectedCurrency,
              //     underline: const SizedBox(),
              //     items: const [
              //       DropdownMenuItem(value: 'TL', child: Text('TL')),
              //       DropdownMenuItem(value: 'USD', child: Text('USD')),
              //       DropdownMenuItem(value: 'EUR', child: Text('EUR')),
              //     ],
              //     onChanged: _updateCurrency,
              //   ),
              // ),
            ],
          ),

          // OYUN AYARLARI - Geçici olarak devre dışı
          _buildSection(
            title: 'settings.gameSettings'.tr(),
            children: [
              _buildListTile(
                icon: Icons.access_time,
                title: 'settings.gameDayDuration'.tr(),
                trailing: DropdownButton<int>(
                  value: _gameDayDuration,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: 1, child: Text('1 ${'misc.minutes'.tr()}')),
                    DropdownMenuItem(value: 2, child: Text('2 ${'misc.minutes'.tr()}')),
                    DropdownMenuItem(value: 5, child: Text('5 ${'misc.minutes'.tr()}')),
                    DropdownMenuItem(value: 10, child: Text('10 ${'misc.minutes'.tr()}')),
                    DropdownMenuItem(value: 15, child: Text('15 ${'misc.minutes'.tr()}')),
                  ],
                  onChanged: _changeGameDayDuration,
                ),
              ),

              // _buildListTile(
              //   icon: Icons.calendar_today,
              //   title: 'Mevcut Oyun Zamanı',
              //   subtitle: _gameTimeService.getFormattedGameTime(),
              //   trailing: const Icon(Icons.info_outline, size: 20),
              // ),
            ],
          ),

          // BİLDİRİM AYARLARI - Geçici olarak devre dışı
          // _buildSection(
          //   title: 'settings.notifications'.tr(),
          //   children: [
          //     _buildSwitchTile(
          //       icon: Icons.new_releases_outlined,
          //       title: 'settings.newListings'.tr(),
          //       value: _notificationNewListings,
          //       onChanged: (value) => _toggleNotification('newListings', value),
          //     ),
          //     _buildSwitchTile(
          //       icon: Icons.trending_down,
          //       title: 'settings.priceDrops'.tr(),
          //       value: _notificationPriceDrops,
          //       onChanged: (value) => _toggleNotification('priceDrops', value),
          //     ),
          //     _buildSwitchTile(
          //       icon: Icons.local_offer_outlined,
          //       title: 'settings.offers'.tr(),
          //       value: _notificationOffers,
          //       onChanged: (value) => _toggleNotification('offers', value),
          //     ),
          //     _buildSwitchTile(
          //       icon: Icons.notifications_outlined,
          //       title: 'settings.system'.tr(),
          //       value: _notificationSystem,
          //       onChanged: (value) => _toggleNotification('system', value),
          //     ),
          //   ],
          // ),

          // Uygulama Bilgisi
          _buildSection(
            title: 'settings.appInfo'.tr(),
            children: [
              _buildListTile(
                icon: Icons.bar_chart,
                title: 'home.statistics'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StatisticsScreen()),
                  );
                },
              ),
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

          // Admin Paneli (Sadece admin görebilir)
          if (_currentUser != null && _authService.isUserAdmin(_currentUser!))
            _buildSection(
              title: 'settings.admin'.tr(),
              children: [
                _buildListTile(
                  icon: Icons.admin_panel_settings,
                  title: 'settings.adminPanel'.tr(),
                  textColor: Colors.redAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
                    );
                  },
                ),
                // ADMIN: Level Up Button (Sadece selimyay123@gmail.com için)
                if (_currentUser?.email == 'selimyay123@gmail.com')
                  _buildListTile(
                    icon: Icons.upgrade,
                    title: 'Admin: Level Up',
                    textColor: Colors.redAccent,
                    onTap: () async {
                      if (_currentUser == null) return;
                      
                      final xpService = XPService();
                      // Bir sonraki seviye için gereken XP'yi hesapla
                      final xpToNext = _currentUser!.xpToNextLevel;
                      
                      // XP ekle ve seviye atlat
                      final result = await xpService.addXP(
                        _currentUser!.id,
                        xpToNext,
                        XPSource.achievement, 
                      );
                      
                      // Dialog ve reklam göster
                      if (result.leveledUp) {
                        await _showLevelUpDialog(result);
                        // Ayarları yenile
                        await _loadSettings();
                      }
                    },
                  ),
                  _buildListTile(
                    icon: Icons.local_offer,
                    title: 'Admin: Fırsat Oluştur',
                    textColor: Colors.redAccent,
                    onTap: () {
                      MarketRefreshService().forceGenerateOpportunity();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fırsat ilanı oluşturuldu!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
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
              // _buildListTile(
              //   icon: Icons.logout,
              //   title: 'settings.logoutButton'.tr(),
              //   textColor: Colors.red,
              //   onTap: _logout,
              // ),
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

