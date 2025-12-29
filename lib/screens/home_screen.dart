import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../services/notification_service.dart';
import '../services/ad_service.dart';
import '../services/xp_service.dart';
import '../services/game_time_service.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import 'login_screen.dart';
// import 'vehicle_category_screen.dart'; // YORUM: Kategori seçimi şimdilik devre dışı, doğrudan otomobil kategorisi
import 'brand_selection_screen.dart'; // Doğrudan marka seçimi için
import 'settings_screen.dart';
import 'my_vehicles_screen.dart';
import 'sell_vehicle_screen.dart';
import 'my_listings_screen.dart';
import 'my_offers_screen.dart';
import 'notifications_screen.dart';
import 'store_screen.dart';
import 'daily_quests_screen.dart';
import '../services/daily_quest_service.dart';
import '../models/daily_quest_model.dart';
import '../widgets/level_up_dialog.dart';
import '../services/daily_login_service.dart';
import '../widgets/daily_login_dialog.dart';
import 'taxi_game_screen.dart';
import 'skill_tree_screen.dart'; // Yetenek Ağacı Ekranı
import 'package:lottie/lottie.dart';
import '../services/rental_service.dart'; // Kiralama Servisi

import '../widgets/game_time_countdown.dart'; // 🆕 Game Time Countdown
import 'activity_screen.dart';
import 'leaderboard_screen.dart';
// import 'social/social_hub_screen.dart';
import '../services/leaderboard_service.dart';
import '../widgets/city_skyline_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  final AdService _adService = AdService();
  final NotificationService _notificationService = NotificationService();
  final XPService _xpService = XPService();
  final DailyQuestService _questService = DailyQuestService();
  final DailyLoginService _loginService = DailyLoginService();
  final GameTimeService _gameTime = GameTimeService();
  final RentalService _rentalService = RentalService();
  User? _currentUser;
  bool _isLoading = true;
  int _vehicleCount = 0;
  int _pendingOffersCount = 0; // Bekleyen teklif sayısı
  List<UserVehicle> _userVehicles = [];
  List<UserVehicle> _userListedVehicles = []; // Satışa çıkarılan araçlar
  
  // Tutorial için GlobalKey'ler
  final GlobalKey _marketButtonKey = GlobalKey();
  final GlobalKey _myVehiclesButtonKey = GlobalKey();
  final GlobalKey _sellVehicleButtonKey = GlobalKey();
  final GlobalKey _offersButtonKey = GlobalKey();
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _gameTimeKey = GlobalKey();

  final GlobalKey _storeButtonKey = GlobalKey(); // Mağaza butonu için key
  final GlobalKey _taxiGameButtonKey = GlobalKey();
  final GlobalKey _myListingsButtonKey = GlobalKey(); // İlanlarım butonu için key
  final GlobalKey _skillTreeButtonKey = GlobalKey(); // Yetenek ağacı butonu için key
  
  // Kiralama geliri animasyonu için
  double _lastRentalIncome = 0.0;
  bool _showRentalIncomeAnimation = false;
  
  // Fire animasyonu için
  bool _showFireAnimation = false;
  
  // Tutorial aktif mi? (scroll'u engellemek için)
  bool _isTutorialActive = false;
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initData();
    // İlk reklam yükleme
    _adService.loadRewardedAd();
    
    // Gün değişimini dinle
    _gameTime.addDayChangeListener(_onGameDayChanged);
  }

  Future<void> _initData() async {
    await _loadCurrentUser();
    if (mounted) {
      _checkDailyStreak();
    }
  }

  @override
  void dispose() {
    _gameTime.removeDayChangeListener(_onGameDayChanged);
    _adService.dispose();
    super.dispose();
  }

  /// Gün değiştiğinde çağrılır
  void _onGameDayChanged(int oldDay, int newDay) async {
    if (!mounted) return;
    
    // Fire animasyonunu tetikle (Teklifler yenileniyor)
    setState(() {
      _showFireAnimation = true;
    });
    
    // 3 saniye sonra animasyonu gizle
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showFireAnimation = false;
        });
      }
    });
    
    // Galeri sahibiyse kiralama geliri işle
    if (_currentUser != null && _currentUser!.ownsGallery) {
      final rentalIncome = await _rentalService.processDailyRental(_currentUser!.id);
      
      if (rentalIncome > 0 && mounted) {
        // Kiralama geliri animasyonunu tetikle
        setState(() {
          _lastRentalIncome = rentalIncome;
          _showRentalIncomeAnimation = true;
        });
        
        // 3 saniye sonra animasyonu gizle
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showRentalIncomeAnimation = false;
            });
          }
        });
      }
    }
    
    // Tekliflerin oluşması için biraz bekle ve yenile
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        await _loadCurrentUser();
        if (mounted) {
          _checkDailyStreak();
        }
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    
    // Kullanıcının araçlarını yükle
    if (user != null) {
      // 24 saatlik bildirim sıfırlama kontrolü (arka planda)
      _notificationService.checkAndResetDailyNotifications(user.id);
      
      final vehicles = await _db.getUserActiveVehicles(user.id);
      final vehicleCount = vehicles.length;
      
      // Kullanıcının satışa çıkardığı araçları yükle
      final listedVehicles = await _db.getUserListedVehicles(user.id);
      
      // Bekleyen teklifleri yükle
      final pendingOffers = await _db.getPendingOffersCount(user.id);
      
      // Günlük kar/zarar sıfırlama kontrolü
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      User updatedUser = user;
      
      // Eğer son sıfırlama tarihi bugün değilse (veya null ise), sıfırla
      if (user.lastDailyResetDate == null || 
          DateTime(user.lastDailyResetDate!.year, user.lastDailyResetDate!.month, user.lastDailyResetDate!.day) != today) {
        
        updatedUser = user.copyWith(
          dailyStartingBalance: user.balance,
          lastDailyResetDate: now,
        );
        
        await _db.updateUser(user.id, updatedUser.toJson());
      }

      setState(() {
        _currentUser = updatedUser;
        _userVehicles = vehicles;
        _vehicleCount = vehicleCount;
        _userListedVehicles = listedVehicles;
        _pendingOffersCount = pendingOffers;
        _isLoading = false;
      });
      
      
      // Günlük giriş bonusunu (Streak) kontrol et
      // _checkDailyStreak(); // ARTIK BURADA ÇAĞIRMIYORUZ (Sonsuz döngü/çift dialog hatası için)
      
      // Günlük görevleri kontrol et/oluştur
      _questService.checkAndGenerateQuests(user.id);
      
      // Liderlik tablosu için verileri senkronize et (Arka planda)
      LeaderboardService().updateUserScore(updatedUser);
      
      // Kullanıcı yüklendikten sonra tutorial'ı kontrol et
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowTutorial();
      });
    } else {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  /// Ödüllü reklam izle
  Future<void> _watchRewardedAd() async {
    await _adService.showRewardedAd(
      onRewarded: (double reward) async {
        // Kullanıcıya ödülü ver (5000 TL)
        if (_currentUser != null) {
          final moneyReward = 5000.0;
          final newBalance = _currentUser!.balance + moneyReward;
          await _db.updateUser(_currentUser!.id, {'balance': newBalance});
          
          // UI'ı güncelle
          await _loadCurrentUser();
          
          // Başarı mesajı göster
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    const Text('🎉 '),
                    Expanded(child: Text('ads.rewardReceived'.tr())),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.attach_money,
                      size: 64,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '+5000 TL',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ads.rewardMessage'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('common.ok'.tr()),
                  ),
                ],
              ),
            );
          }
        }
      },
      onAdNotReady: () {
        // Reklam hazır değil
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              behavior: SnackBarBehavior.floating,
              content: Text('ads.notReady'.tr()),
              backgroundColor: Colors.orange.withOpacity(0.8),
              duration: const Duration(seconds: 2),
            ),
          );
          // Yeni reklam yükle
          _adService.loadRewardedAd();
        }
      },
    );
  }

  Future<void> _logout() async {
    // Onay dialogu göster
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('auth.logout'.tr()),
        content: Text('auth.logoutConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('auth.logout'.tr()),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Çıkış yap
      await _authService.logout();
      
      if (!mounted) return;
      
      // Giriş ekranına yönlendir
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder ile dil değişikliklerini dinle
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            // title: Text('CEBİNDEN'),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              // Bildirim butonu - Badge ile
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'home.notifications'.tr(),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      ).then((_) => setState(() {})); // Geri dönünce refresh et
                    },
                  ),
                  // Badge - okunmamış sayısı
                  if (_currentUser != null)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: FutureBuilder<int>(
                        future: NotificationService().getUnreadCount(_currentUser!.id),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          
                          return Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              count > 99 ? '99+' : count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'activity.title'.tr(),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ActivityScreen(),
                    ),
                  );
                },
              ),
              /*
              IconButton(
                icon: const Icon(Icons.people, color: Colors.blueAccent),
                tooltip: 'Sosyal',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SocialHubScreen(),
                    ),
                  );
                },
              ),
              */
              IconButton(
                icon: const Icon(Icons.leaderboard, color: Colors.amber),
                tooltip: 'Liderlik Tablosu',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'auth.logout'.tr(),
                onPressed: _logout,
              ),
            ],
          ),
          drawer: _buildDrawer(context),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/home_bg.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: RefreshIndicator(
                    onRefresh: _loadCurrentUser,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Column(
                                children: [
                                  // Profil ve Bakiye Kartı
                                  _buildProfileCard(),

                                  // 🆕 Reklam Kartı (Loot Box) - Profilin hemen altına taşındı
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: _buildWatchAdCard(),
                                  ),
                                  const SizedBox(height: 16),

                                  // XP Progress Kartı - Kaldırıldı (Profile entegre edildi)
                                  // _buildXPCard(),
                                  
                                  // const SizedBox(height: 16),

                                  // 🆕 Oyun Zamanı Sayacı - XP'nin altına taşındı
                                  GameTimeCountdown(key: _gameTimeKey),
                                  const SizedBox(height: 16),
                                  
                                  // Hızlı İşlemler
                                  // _buildQuickActions(), // YORUM: SliverGrid olarak aşağıya taşındı
                                  
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Hızlı İşlemler (SliverGrid)
                        _buildQuickActionsSliver(),
                        
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  
                                  // Galeri Satın Al (sadece galeri sahibi değilse göster)
                                  if (_currentUser != null && !_currentUser!.ownsGallery)
                                    _buildBuyGalleryButton(),
                                  
                                  if (_currentUser != null && !_currentUser!.ownsGallery)
                                    const SizedBox(height: 16),
                                  
                                  // Galerim (sadece galeri sahibiyse göster)
                                  if (_currentUser != null && _currentUser!.ownsGallery)
                                    _buildMyGallerySection(),
                                  
                                  if (_currentUser != null && _currentUser!.ownsGallery)
                                    const SizedBox(height: 16),
                                  
                                  // İstatistikler - Ayarlara taşındı
                                  // _buildStatistics(),
                                  
                                  // const SizedBox(height: 16),
                                  
                                  // Son İşlemler veya Bilgilendirme - Kaldırıldı
                                  // _buildRecentActivity(),
                                  
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                        

                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  // Glassmorphism Container Helper
  Widget _buildGlassContainer({
    Key? key,
    required Widget child, 
    EdgeInsetsGeometry? padding, 
    EdgeInsetsGeometry? margin,
    double borderRadius = 16,
  }) {
    // Performans için blur efekti tamamen kaldırıldı.
    // Sadece yarı saydam beyaz zemin kullanılıyor.
    return Container(
      key: key,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5), // Blur yerine yüksek opaklıkta beyaz
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // Profil ve Bakiye Kartı
  // Rütbe Başlığı
  String _getRankTitle(int level) {
    if (level <= 5) return 'home.ranks.rookie'.tr();
    if (level <= 15) return 'home.ranks.speedster'.tr();
    if (level <= 30) return 'home.ranks.asphaltBeast'.tr();
    if (level <= 50) return 'home.ranks.cityRuler'.tr();
    return 'home.ranks.legend'.tr();
  }

  // Rütbe Rengi
  Color _getRankColor(int level) {
    if (level <= 5) return Colors.greenAccent;
    if (level <= 15) return Colors.cyanAccent;
    if (level <= 30) return Colors.orangeAccent;
    if (level <= 50) return Colors.purpleAccent;
    return Colors.amberAccent; // Gold for Legend
  }

  Widget _buildProfileCard() {
    if (_currentUser == null) return const SizedBox.shrink();
    
    final isProfit = _currentUser!.profitLossPercentage >= 0;
    final rankColor = _getRankColor(_currentUser!.level);
    
    // RepaintBoundary ile sarmalayarak gereksiz yeniden çizmeleri önlüyoruz
    return RepaintBoundary(
      child: Container(
        key: _balanceKey,
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.withOpacity(0.6), Colors.deepPurple.shade400.withOpacity(0.6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Arka Plan - Şehir Silüeti
              Positioned.fill(
                child: CustomPaint(
                  painter: CitySkylinePainter(
                    color: Colors.black.withOpacity(0.15),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profil Resmi ve Çerçeve
                    const SizedBox(height: 10),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow Efekti
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: rankColor.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        // Çerçeve
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [rankColor, rankColor.withOpacity(0.5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3), // Çerçeve kalınlığı
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                backgroundColor: Colors.deepPurple.shade100,
                                backgroundImage: (_currentUser?.profileImageUrl != null && _currentUser!.profileImageUrl!.isNotEmpty)
                                    ? AssetImage(_currentUser!.profileImageUrl!)
                                    : null,
                                child: _currentUser?.profileImageUrl == null
                                    ? Text(
                                        _currentUser!.username[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple.shade700,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        // Seviye Rozeti (Avatarın altında)
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: rankColor,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'Lv. ${_currentUser!.level}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Kullanıcı Bilgileri
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Kullanıcı Adı
                        Text(
                          _currentUser!.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Rütbe Başlığı
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: rankColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getRankTitle(_currentUser!.level).toUpperCase(),
                            style: TextStyle(
                              color: rankColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                        
                        // Toplam Para (Animasyonlu)
                        Text(
                          'home.balance'.tr(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: _currentUser!.balance - (_showRentalIncomeAnimation ? _lastRentalIncome : 0),
                                  end: _currentUser!.balance,
                                ),
                                duration: const Duration(seconds: 2),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return Text(
                                    '${_formatCurrency(value)} ${'common.currency'.tr()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              
                              // Kiralama Geliri Göstergesi (Animasyonlu)
                              if (_showRentalIncomeAnimation)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 500),
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(0, 20 * (1 - value)), // Aşağıdan yukarı kayma
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '+${_formatCurrency(_lastRentalIncome)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Kar/Zarar Göstergesi
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isProfit ? Icons.trending_up : Icons.trending_down,
                                color: isProfit ? Colors.greenAccent : Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '%${_currentUser!.profitLossPercentage.toStringAsFixed(1)} (${_formatCurrency(_currentUser!.totalProfitLoss)})',
                                style: TextStyle(
                                  color: isProfit ? Colors.greenAccent : Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // XP Bölümü
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seviye ${_currentUser!.level}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _currentUser!.levelProgress,
                                backgroundColor: Colors.black.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_currentUser!.xp} XP',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Altın Al Butonu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Mevcut Altın
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentUser!.gold.toStringAsFixed(2),
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Altın Al Butonu
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const StoreScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.deepPurple,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'home.buyGold'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
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
  

  


  Widget _buildWatchAdCard() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 90, // Biraz daha yüksek
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ana Kart
          InkWell(
            onTap: _watchRewardedAd,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E003E), // Dark Purple
                    Colors.deepPurple.shade700,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Sol Taraf - Chest Animasyonu
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: Transform.scale(
                        scale: 1.2, // Animasyonu biraz büyüt
                        child: Lottie.asset(
                          'assets/animations/ad_chest.json',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  
                  // Orta Kısım - Yazılar
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'common.ads.freeMoney'.tr(), // Kısaltılmış metin
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ads.watchAd'.tr().toUpperCase(), // "REKLAM İZLE" -> "KUTUYU AÇ" olarak değişmeli çeviride veya burada override edilebilir
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Sağ Taraf - Ok İkonu
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.amber,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // FREE Badge (Sağ Üst Köşe - Wiggle Animation)
          Positioned(
            top: -6,
            right: 20,
            child: WiggleBadge(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.redAccent, Colors.red],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  'common.free'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hızlı İşlemler (SliverGrid Versiyonu - Optimize Edilmiş)
  Widget _buildQuickActionsSliver() {
    final quickActions = _getQuickActions();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final action = quickActions[index];
            
            // Tutorial için key'leri atıyoruz
            Key? buttonKey;
            if (index == 0) {
              buttonKey = _marketButtonKey;
            } else if (index == 1) {
              buttonKey = _sellVehicleButtonKey;
            } else if (index == 2) {
              buttonKey = _myVehiclesButtonKey;
            } else if (index == 3) { // İlanlarım butonu
              buttonKey = _myListingsButtonKey;
            } else if (index == 4) {
              buttonKey = _offersButtonKey;
            } else if (index == 5) { // Yetenek Ağacı butonu
              buttonKey = _skillTreeButtonKey;
            } else if (index == 6) { // Mağaza butonu
              buttonKey = _storeButtonKey;
            } else if (index == 7) {
              buttonKey = _taxiGameButtonKey;
            }
            
            return _buildActionButton(
              key: buttonKey,
              icon: action['icon'] as IconData?,
              imagePath: action['imagePath'] as String?,
              label: action['label'] as String,
              color: action['color'] as Color,
              onTap: action['onTap'] as VoidCallback,
              badge: action['badge'] as int?,
              reward: action['reward'] as String?,
              animationPath: action['animationPath'] as String?,
              showAnimation: action['showAnimation'] as bool? ?? false,
            );
          },
          childCount: quickActions.length,
        ),
      ),
    );
  }

  // Hızlı İşlemler Listesi
  List<Map<String, dynamic>> _getQuickActions() {
    return [
      {
        'imagePath': 'assets/home_images/buy.png',
        'label': 'home.buyVehicle'.tr(),
        'color': Colors.blue,
        'onTap': () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrandSelectionScreen(
                categoryName: 'vehicles.categoryAuto'.tr(),
                categoryColor: Colors.blue,
              ),
            ),
          );
          await _loadCurrentUser();
        },
      },
      {
        'imagePath': 'assets/home_images/sell.png',
        'label': 'home.sellVehicle'.tr(),
        'color': Colors.orange,
        'onTap': () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SellVehicleScreen(),
            ),
          );
          await _loadCurrentUser();
        },
      },
      {
        'imagePath': 'assets/home_images/garage.png',
        'label': 'home.myVehicles'.tr(),
        'color': Colors.green,
        'badge': _vehicleCount > 0 ? _vehicleCount : null,
        'onTap': () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyVehiclesScreen(),
            ),
          );
          await _loadCurrentUser();
        },
      },
      {
        'imagePath': 'assets/home_images/listings.png',
        'label': 'home.myListings'.tr(),
        'color': Colors.purple,
        'badge': _userListedVehicles.length > 0 ? _userListedVehicles.length : null,
        'onTap': () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyListingsScreen(),
            ),
          );
          await _loadCurrentUser();
        },
      },
      {
        'imagePath': 'assets/home_images/offers.png',
        'label': 'home.myOffers'.tr(),
        'color': Colors.teal,
        'badge': _pendingOffersCount > 0 ? _pendingOffersCount : null,
        'animationPath': 'assets/animations/fire.json',
        'showAnimation': _showFireAnimation,
        'onTap': () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyOffersScreen(),
            ),
          );
          await _loadCurrentUser();
        },
      },
      {
        'imagePath': 'assets/home_images/skills.png',
        'label': 'home.tasks'.tr(),
        'color': Colors.indigo,
        'badge': (_currentUser?.skillPoints ?? 0) > 0 ? (_currentUser!.skillPoints) : null,
        'onTap': () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SkillTreeScreen(),
            ),
          );
          await _loadCurrentUser();
        },
      },
      {
        'imagePath': 'assets/home_images/store.png',
        'label': 'store.title'.tr(),
        'color': Colors.deepOrange,
        'onTap': () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StoreScreen(),
            ),
          );
          await _loadCurrentUser();
        },
      },
      {
        'imagePath': 'assets/home_images/taxi.png',
        'label': 'home.taxi'.tr(),
        'color': Colors.amber,
        'onTap': () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TaxiGameScreen(),
            ),
          );
          await _loadCurrentUser();
        },
      },
    ];
  }

  Widget _buildActionButton({
    Key? key, // Tutorial için key parametresi
    IconData? icon,
    String? imagePath,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int? badge, // Badge parametresi ekledik
    String? reward, // Ödül gösterimi için
    String? animationPath, // Animasyon dosyası yolu
    bool showAnimation = false, // Animasyon gösterilsin mi?
  }) {
    return InkWell(
      key: key, // Key'i burada kullanıyoruz
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _buildGlassContainer(
        padding: EdgeInsets.zero, // Padding'i kaldırdık, içeriği kendimiz yöneteceğiz
        child: Stack(
          alignment: Alignment.center,
          children: [
            // İkon (Ortalanmış ve biraz yukarıda)
            Positioned(
              top: 10,
              bottom: 30, // Alt kısımdan banner için yer bırakıyoruz
              left: 0,
              right: 0,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: imagePath != null ? EdgeInsets.zero : const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: imagePath != null ? Colors.transparent : color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: imagePath != null
                          ? Image.asset(
                              imagePath,
                              width: 80,
                              height: 80,
                              fit: BoxFit.contain,
                            )
                          : Icon(
                              icon,
                              color: color,
                              size: 28,
                            ),
                    ),
                    

                      
                    // Animasyon (Fire vb.)
                    if (showAnimation && animationPath != null)
                      Positioned(
                        right: -10,
                        top: -10,
                        child: Lottie.asset(
                          animationPath,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Banner / Tabela (En altta)
            Positioned(
              bottom: 12, // Ayakları kaldırdık, konumu koruduk
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.8), // Koyu mor renk (Reklam kartı ile uyumlu)
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    label.toUpperCase().split(' ').first, // Sadece ilk kelimeyi alıp BÜYÜK HARF yapıyoruz
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13, // Yazıyı biraz büyüttük
                      fontWeight: FontWeight.w800, // Daha kalın
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),

            // Badge (Bildirim sayısı) - Sağ üst köşe
            if (badge != null && badge > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  child: Center(
                    child: Text(
                      badge > 99 ? '99+' : badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            // Ödül gösterimi
            if (reward != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reward,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }



  // ============================================================================
  // YORUM: Garaj/Galeri Özelliği - İleride farklı kurgu için ayrılmış
  // Şimdilik "Araçlarım" butonu direkt MyVehiclesScreen sayfasına gidiyor
  // ============================================================================
  
  /*
  // Kullanıcının Araçları (Dashboard'da özet gösterim)
  Widget _buildMyVehicles() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.garage, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text(
                    'Garajım',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              if (_vehicleCount > 0)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyVehiclesScreen(),
                      ),
                    );
                  },
                  child: Text('home.viewAll'.tr()),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Araç listesi
          if (_vehicleCount == 0)
            // Hiç araç yok
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz aracınız yok',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İlk aracınızı satın alarak garajınızı oluşturun!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // YORUM: Kategori seçim sayfası devre dışı, doğrudan otomobil kategorisi
                      // final purchased = await Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => const VehicleCategoryScreen(),
                      //   ),
                      // );
                      
                      // Doğrudan marka seçim sayfasına git (Otomobil kategorisi)
                      final purchased = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrandSelectionScreen(
                            categoryName: 'vehicles.categoryAuto'.tr(), // Otomobil kategorisi
                            categoryColor: Colors.blue,
                          ),
                        ),
                      );
                      if (purchased == true) {
                        await _loadCurrentUser();
                      }
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: Text('misc.buyVehicleButton'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Araçları göster (maksimum 3 tane)
            Column(
              children: _userVehicles.take(3).map((vehicle) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.directions_car,
                          color: Colors.deepPurple,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.fullName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${vehicle.year} • ${_formatNumber(vehicle.mileage)} km',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Satın alma: ${_formatCurrency(vehicle.purchasePrice)} TL',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                          const SizedBox(height: 4),
                          Text(
                            '${vehicle.daysOwned}g',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          
          if (_vehicleCount > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${_vehicleCount - 3} araç daha...',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
  */

  // Galeri Satın Al Butonu
  // Galeri Satın Al Butonu
  Widget _buildBuyGalleryButton() {
    const galleryPrice = 10000000.0; // 10 Milyon TL

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showGalleryInfoDialog(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade800, Colors.deepPurple.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Arka Plan Deseni (Şehir Silüeti)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: 0.3,
                      child: CustomPaint(
                        painter: CitySkylinePainter(
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    // Sol taraf - Animasyon
                    Lottie.asset(
                      'assets/animations/gallery.json',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 16),
                    
                    // Orta taraf - Bilgiler
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'home.buyGallery'.tr(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'home.professionalBusiness'.tr(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Fiyat Etiketi
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${_formatCurrency(galleryPrice)} TL',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Sağ taraf - Ok İkonu
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  // Galeri Satın Alma İşlemi
  Future<void> _purchaseGallery() async {
    const galleryPrice = 10000000.0; // 10 Milyon TL
    
    if (_currentUser == null) return;
    
    // Bakiye kontrolü
    if (_currentUser!.balance < galleryPrice) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          content: Text('home.galleryInsufficientFunds'.tr()),
          backgroundColor: Colors.red.withOpacity(0.8),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.store_mall_directory, color: Colors.deepPurple),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'home.buyGallery'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'home.galleryPrice'.tr() + ': ${_formatCurrency(galleryPrice)} TL\n\n' +
          'common.continue'.tr() + '?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: Text('common.continue'.tr()),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // Satın alma işlemi
    final newBalance = _currentUser!.balance - galleryPrice;
    final updatedUser = _currentUser!.copyWith(
      balance: newBalance,
      ownsGallery: true,
      galleryPurchaseDate: DateTime.now(),
    );
    
    await _db.updateUser(_currentUser!.id, updatedUser.toJson());
    
    // UI'ı güncelle
    await _loadCurrentUser();
    
    if (!mounted) return;
    
    // Başarı mesajı
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'home.galleryPurchaseSuccess'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.store_mall_directory,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'home.galleryDescription'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
            ),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }

  // Galerim Bölümü
  Widget _buildMyGallerySection() {
    if (_currentUser == null || !_currentUser!.ownsGallery) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700.withOpacity(0.9), Colors.deepPurple.shade500.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Lottie.asset(
                'assets/animations/gallery.json',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'home.myGallery'.tr(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'home.galleryStatus'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'common.active'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Kiraya Ver Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showRentOutDialog,
              icon: const Icon(Icons.key),
              label: Text('gallery.rentOut'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Kiradaki Araçlar Listesi
          _buildRentedVehiclesList(),
        ],
      ),
    );
  }

  Widget _buildRentedVehiclesList() {
    // Kiradaki araçları filtrele
    final rentedVehicles = _userVehicles.where((v) => v.isRented).toList();

    if (rentedVehicles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'gallery.noRentedVehicles'.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'gallery.rentedVehicles'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rentedVehicles.length,
          itemBuilder: (context, index) {
            final vehicle = rentedVehicles[index];
            final dailyIncome = vehicle.purchasePrice * RentalService.dailyRentalRate;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.fullName.replaceAll('Serisi', 'vehicles.series'.tr()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${'gallery.dailyIncome'.tr()}: ${_formatCurrency(dailyIncome)} TL',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
                    tooltip: 'gallery.stopRenting'.tr(),
                    onPressed: () async {
                      await _rentalService.stopRentingVehicle(vehicle.id);
                      _loadCurrentUser(); // Listeyi yenile
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showRentOutDialog() async {
    // Kiralanabilir araçları getir
    final rentableVehicles = await _rentalService.getRentableVehicles(_currentUser!.id);
    
    if (!mounted) return;

    if (rentableVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 8,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('gallery.noRentableVehicles'.tr()),
          backgroundColor: Colors.orange.withOpacity(0.8),
        ),
      );
      return;
    }

    // Seçilen araçları tutmak için set
    final selectedVehicleIds = <String>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('gallery.rentOutTitle'.tr()),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rentableVehicles.length,
              itemBuilder: (context, index) {
                final vehicle = rentableVehicles[index];
                final dailyIncome = vehicle.purchasePrice * RentalService.dailyRentalRate;
                final isSelected = selectedVehicleIds.contains(vehicle.id);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        selectedVehicleIds.add(vehicle.id);
                      } else {
                        selectedVehicleIds.remove(vehicle.id);
                      }
                    });
                  },
                  title: Text(vehicle.fullName.replaceAll('Serisi', 'vehicles.series'.tr())),
                  subtitle: Text(
                    '${'gallery.dailyIncome'.tr()}: ${_formatCurrency(dailyIncome)} TL',
                    style: const TextStyle(color: Colors.green),
                  ),
                  secondary: const Icon(Icons.car_rental),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: selectedVehicleIds.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      
                      // Seçilen araçları kiraya ver
                      for (final vehicleId in selectedVehicleIds) {
                        await _rentalService.rentVehicle(vehicleId);
                      }
                      
                      // Başarı mesajı
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('gallery.rentSuccess'.tr()),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      
                      // Ekranı yenile
                      _loadCurrentUser();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('gallery.rentOut'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  // Galeri Avantaj Item
  Widget _buildGalleryBenefit({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
            ),
          ),
        ),
        Icon(
          Icons.check_circle,
          color: Colors.white,
          size: 16,
        ),
      ],
    );
  }

  // Galeri Bilgilendirme Dialog'u
  void _showGalleryInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.store_mall_directory,
                color: Colors.deepPurple,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'home.galleryOwner'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'home.galleryDescription'.tr(),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              
              // Avantajlar
              Text(
                'home.galleryAdvantages'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.car_rental,
                title: 'home.rentalService'.tr(),
                description: 'home.advantage1Desc'.tr(),
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.trending_down,
                title: 'home.opportunityPurchases'.tr(),
                description: 'home.advantage2Desc'.tr(),
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.trending_up,
                title: 'home.highProfitMargin'.tr(),
                description: 'home.advantage3Desc'.tr(),
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.workspace_premium,
                title: 'home.prestigeReputation'.tr(),
                description: 'home.advantage4Desc'.tr(),
              ),
              
              const SizedBox(height: 20),
              
              // Fiyat Bilgisi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.deepPurple.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'home.galleryPrice'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'home.galleryPriceValue'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // İptal Butonu
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'common.cancel'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Devam Et Butonu
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _purchaseGallery();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: Text(
              'common.continue'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Avantaj Item Widget
  Widget _buildAdvantageItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.deepPurple,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  // İlanlarım (Satışa çıkarılan araçlar)
  Widget _buildMyListings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.store, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text(
                      'home.myListings'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_userListedVehicles.length} ${'home.listingCount'.tr()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // İlan listesi
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _userListedVehicles.length > 3 ? 3 : _userListedVehicles.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final vehicle = _userListedVehicles[index];
              return _buildListingCard(vehicle);
            },
          ),
          
          // Tümünü gör butonu (eğer 3'ten fazla ilan varsa)
          if (_userListedVehicles.length > 3)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () {
                  // TODO: Tüm ilanları göster
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('home.viewAllListingsComingSoon'.tr()),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text('${'home.viewAllListings'.tr()} (${_userListedVehicles.length})'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // İlan kartı
  Widget _buildListingCard(UserVehicle vehicle) {
    return InkWell(
      onTap: () {
        // TODO: İlan detay sayfasına git
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('home.listingDetailComingSoon'.tr()),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Araç ikonu
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_car,
                color: Colors.green,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            
            // Araç bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vehicle.year} • ${_formatNumber(vehicle.mileage)} km',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatCurrency(vehicle.listingPrice ?? 0)} TL',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            
            // Tarih ve durum
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'common.active'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${vehicle.daysOwned} ${'misc.days'.tr()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Para formatı
  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // Sayı formatı (1000 → 1.000)
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // Drawer (Yan Menü)
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 50,
                bottom: 30,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.deepPurple.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profil Resmi
                  const SizedBox(height: 20), // Resim biraz aşağı kaydırıldı
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      backgroundImage: _currentUser?.profileImageUrl != null
                          ? AssetImage(_currentUser!.profileImageUrl!)
                          : null,
                      child: _currentUser?.profileImageUrl == null
                          ? (_currentUser != null
                              ? Text(
                                  _currentUser!.username[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple.shade700,
                                  ),
                                )
                              : const Icon(Icons.person, size: 40))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Kullanıcı Adı
                  if (_currentUser != null) ...[
                    Text(
                      _currentUser!.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                Text(
                  '${_formatCurrency(_currentUser!.balance)} ${'common.currency'.tr()}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                  ],
                ],
              ),
            ),
            
            // Menü Öğeleri
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    title: 'drawer.dashboard'.tr(),
                    onTap: () {
                      Navigator.pop(context); // Drawer'ı kapat
                      // Zaten dashboard'dayız, bir şey yapmaya gerek yok
                    },
                    isSelected: true, // Dashboard seçili
                  ),
                  _buildDrawerItem(
                  icon: Icons.school,
                  title: 'tutorial.title'.tr(),
                  onTap: () {
                    Navigator.pop(context); // Drawer'ı kapat
                    // Tutorial'ı başlat
                    _showTutorial();
                  },
                ),
                  _buildDrawerItem(
                    icon: Icons.assignment,
                    title: 'quests.title'.tr(),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DailyQuestsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.shopping_cart,
                    title: 'drawer.buyVehicle'.tr(),
                    onTap: () async {
                      Navigator.pop(context); // Drawer'ı kapat
                      
                      // YORUM: Kategori seçim sayfası devre dışı, doğrudan otomobil kategorisi
                      // final purchased = await Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => const VehicleCategoryScreen(),
                      //   ),
                      // );
                      
                      // Doğrudan marka seçim sayfasına git (Otomobil kategorisi)
                      final purchased = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrandSelectionScreen(
                            categoryName: 'vehicles.categoryAuto'.tr(), // Otomobil kategorisi
                            categoryColor: Colors.blue,
                          ),
                        ),
                      );
                      
                      // Eğer satın alma başarılıysa, dashboard'u yenile
                      if (purchased == true) {
                        await _loadCurrentUser();
                      }
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.sell,
                    title: 'drawer.sellVehicle'.tr(),
                    onTap: () async {
                      Navigator.pop(context); // Drawer'ı kapat
                      // Araç satış sayfasına git
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SellVehicleScreen(),
                        ),
                      );
                      
                      // Eğer işlem başarılıysa, dashboard'u yenile
                      if (result == true) {
                        await _loadCurrentUser();
                      }
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.local_offer,
                    title: 'drawer.myOffers'.tr(),
                    badge: _pendingOffersCount > 0 ? _pendingOffersCount : null,
                    onTap: () async {
                      Navigator.pop(context); // Drawer'ı kapat
                      // Teklifler sayfasına git
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyOffersScreen(),
                        ),
                      );
                      // Sayfa kapanınca dashboard'u yenile
                      await _loadCurrentUser();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.leaderboard,
                    title: 'drawer.leaderboard'.tr(),
                    onTap: () {
                      Navigator.pop(context); // Drawer'ı kapat
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LeaderboardScreen(),
                        ),
                      );
                    },
                  ),
                  // _buildDrawerItem(
                  //   icon: Icons.car_rental,
                  //   title: 'Araç Kirala',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     // TODO: Araç kiralama sayfasına git
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       const SnackBar(
                  //         content: Text('Araç kiralama sayfası yakında...'),
                  //         duration: Duration(seconds: 2),
                  //       ),
                  //     );
                  //   },
                  // ),
                  // GÖREVLER - Geçici olarak devre dışı
                  // _buildDrawerItem(
                  //   icon: Icons.task_alt,
                  //   title: 'drawer.tasks'.tr(),
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     // TODO: Görevler sayfasına git
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       SnackBar(
                  //         content: Text('drawer.tasksComingSoon'.tr()),
                  //         duration: const Duration(seconds: 2),
                  //       ),
                  //     );
                  //   },
                  // ),
                  const Divider(height: 1),
                ],
              ),
            ),
            
            // Ayarlar (En Altta)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: _buildDrawerItem(
                icon: Icons.settings,
                title: 'drawer.settings'.tr(),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  // Ayarlardan dönünce kullanıcı verilerini güncelle (örn. profil resmi değişmiş olabilir)
                  if (mounted) {
                    _loadCurrentUser();
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Drawer Menü Öğesi
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    int? badge, // Badge parametresi
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.deepPurple : Colors.grey[700],
        size: 24,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.deepPurple : Colors.grey[800],
              ),
            ),
          ),
          // Badge
          if (badge != null && badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge > 99 ? '99+' : badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      selected: isSelected,
      selectedTileColor: Colors.deepPurple.withOpacity(0.1),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 4,
      ),
    );
  }

  // ========== TUTORIAL SİSTEMİ ==========

  /// İlk açılış kontrolü ve tutorial gösterimi
  Future<void> _checkAndShowTutorial() async {
    // Tutorial kontrolü - Artık User modelinden kontrol ediliyor
    if (_currentUser == null) return;
    
    final tutorialCompleted = _currentUser!.isTutorialCompleted;
    
    // Tutorial daha önce gösterilmediyse ve kullanıcı giriş yapmışsa göster
    if (!tutorialCompleted && mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      _showTutorial();
    }
  }

  /// Tutorial'ı tamamlandı olarak işaretle
  Future<void> _setTutorialCompleted() async {
    if (_currentUser == null) return;
    
    try {
      // Firestore'da güncelle
      final updatedUser = _currentUser!.copyWith(isTutorialCompleted: true);
      await _db.updateUser(_currentUser!.id, updatedUser.toJson());
      
      // Local state'i güncelle
      setState(() {
        _currentUser = updatedUser;
      });
      
      // SharedPreferences'ı da güncelle (yedek olarak)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_completed', true);
    } catch (e) {
      print('Error updating tutorial status: $e');
    }
  }

  /// Tutorial'ı göster
  void _showTutorial() {
    // Tutorial zaten gösterildiyse veya aktifse gösterme
    if (_isTutorialActive) return;

    setState(() {
      _isTutorialActive = true;
    });

    // Eğer sayfa aşağı kaydırılmışsa önce yukarı kaydır
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ).then((_) {
        if (!mounted) return;
        _startTutorialPart1();
      });
    } else {
      _startTutorialPart1();
    }
  }

  void _startTutorialPart1() {
    // Bölüm 1'i başlat
    TutorialCoachMark(
      targets: _createTutorialTargetsPart1(),
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        // Bölüm 1 bittiğinde scroll yap ve Bölüm 2'yi başlat
        _startTutorialPart2();
      },
      onClickTarget: (target) {
        // Tıklanan hedefe göre özel işlemler yapılabilir
      },
      onClickOverlay: (target) {
        // Overlay'e tıklandığında sonraki adıma geç
      },
      onSkip: () {
        _setTutorialCompleted();
        setState(() {
          _isTutorialActive = false;
        });
        return true;
      },
    ).show(context: context);
  }

  void _startTutorialPart2() {
    // Scroll işlemi
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        350.0, // Grid'in görünür olacağı tahmini pozisyon
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ).then((_) {
        // Scroll bittikten sonra Bölüm 2'yi başlat
        if (!mounted) return;
        
        TutorialCoachMark(
          targets: _createTutorialTargetsPart2(),
          colorShadow: Colors.black,
          textSkip: "SKIP",
          paddingFocus: 10,
          opacityShadow: 0.8,
          onFinish: () {
            // Bölüm 2 bittiğinde Bölüm 3'e geç
            _startTutorialPart3();
          },
          onSkip: () {
            _setTutorialCompleted();
            setState(() {
              _isTutorialActive = false;
            });
            return true;
          },
        ).show(context: context);
      });
    } else {
      // Scroll yapılamazsa direkt başlat (fallback)
      TutorialCoachMark(
        targets: _createTutorialTargetsPart2(),
        colorShadow: Colors.black,
        textSkip: "SKIP",
        paddingFocus: 10,
        opacityShadow: 0.8,
        onFinish: () {
          _startTutorialPart3();
        },
        onSkip: () {
          _setTutorialCompleted();
          setState(() {
            _isTutorialActive = false;
          });
          return true;
        },
      ).show(context: context);
    }
  }

  void _startTutorialPart3() {
    // Bölüm 3 için scroll işlemi
    if (_scrollController.hasClients) {
      Future scrollFuture;
      
      // Eğer Teklifler butonu zaten render edilmişse ona odaklan
      if (_offersButtonKey.currentContext != null) {
        scrollFuture = Scrollable.ensureVisible(
          _offersButtonKey.currentContext!,
          alignment: 0.5, // Ekranda ortala
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        // Render edilmemişse (ekran dışındaysa) biraz aşağı kaydır
        scrollFuture = _scrollController.animateTo(
          _scrollController.offset + 200.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }

      scrollFuture.then((_) {
        if (!mounted) return;
        
        TutorialCoachMark(
          targets: _createTutorialTargetsPart3(),
          colorShadow: Colors.black,
          textSkip: "SKIP",
          paddingFocus: 10,
          opacityShadow: 0.8,
          onFinish: () {
            _setTutorialCompleted();
            setState(() {
              _isTutorialActive = false;
            });
          },
          onSkip: () {
            _setTutorialCompleted();
            setState(() {
              _isTutorialActive = false;
            });
            return true;
          },
        ).show(context: context);
      });
    }
  }

  void _scrollToTarget(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        alignment: 0.5, // Ortala
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Tutorial Bölüm 1 (Scroll gerektirmeyen üst kısım)
  List<TargetFocus> _createTutorialTargetsPart1() {
    return [
      // ADIM 1: Bakiye ve Altın
      TargetFocus(
        identify: "balance",
        keyTarget: _balanceKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step1_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step1_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 2: Oyun Zamanı
      TargetFocus(
        identify: "game_time",
        keyTarget: _gameTimeKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.top, // Düzeltildi: Üstte görünsün
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step2_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step2_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '2/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),


    ];
  }

  /// Tutorial Bölüm 2 (Scroll gerektiren alt kısım)
  /// Tutorial Bölüm 2 (Scroll gerektiren alt kısım)
  List<TargetFocus> _createTutorialTargetsPart2() {
    return [
      // ADIM 4: Market Butonu
      TargetFocus(
        identify: "market_button",
        keyTarget: _marketButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step4_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step4_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '4/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ADIM 5: Araç Sat Butonu
      TargetFocus(
        identify: "sell_vehicle_button",
        keyTarget: _sellVehicleButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step5_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step5_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '5/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 6: Garajım Butonu
      TargetFocus(
        identify: "my_vehicles_button",
        keyTarget: _myVehiclesButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step6_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step6_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '6/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 7: İlanlarım
      TargetFocus(
        identify: "my_listings_button",
        keyTarget: _myListingsButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step7_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step7_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '7/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }
  
  /// Tutorial Bölüm 3 (En alt kısım)
  List<TargetFocus> _createTutorialTargetsPart3() {
    return [
      // ADIM 8: Tekliflerim
      TargetFocus(
        identify: "offers_button",
        keyTarget: _offersButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step8_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step8_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '8/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 9: Yetenek Ağacı
      TargetFocus(
        identify: "skill_tree_button",
        keyTarget: _skillTreeButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step9_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step9_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '9/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 10: Mağaza
      TargetFocus(
        identify: "store_button",
        keyTarget: _storeButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step10_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step10_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '10/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 11: Taksi Oyunu
      TargetFocus(
        identify: "taxi_game_button",
        keyTarget: _taxiGameButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        focusAnimationDuration: const Duration(milliseconds: 600),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tutorial.step11_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step11_desc'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '11/11',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          controller.next();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'tutorial.finish'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }
  
  // ========== XP SİSTEMİ METODLARI ==========
  
  // ========== GÜNLÜK GİRİŞ (STREAK) SİSTEMİ ==========
  
  /// Günlük giriş bonusunu kontrol et ve dialog göster
  Future<void> _checkDailyStreak() async {
    if (_currentUser == null) return;
    
    // Servisten kontrol et
    final status = await _loginService.checkStreak(_currentUser!.id);
    
    // Eğer ödül alınabilirse dialog göster
    if (status['canClaim'] == true && mounted) {
      // İLK GİRİŞ KONTROLÜ:
      // Eğer kullanıcı ilk kez ödül alacaksa (lastDailyRewardDate == null)
      // Dialog gösterme, sessizce ödülü ver ve geç (Burası 0. gün sayılır)
      if (_currentUser?.lastDailyRewardDate == null && status['streak'] == 1) {
        await _loginService.claimReward(_currentUser!.id);
        await _loadCurrentUser(); // Kullanıcıyı güncelle
        return;
      }

      // Biraz gecikmeli göster ki UI yüklensin
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false, // Ödül almadan kapatamasın (isteğe bağlı)
        builder: (context) => DailyLoginDialog(
          userId: _currentUser!.id,
          currentStreak: status['streak'],
          onClaim: () async {
            // Ödül alındıktan sonra kullanıcıyı yenile ve konfeti patlat
            await _loadCurrentUser();
            
            // 🎯 Günlük Görev Güncellemesi: Günlük Giriş
            await _questService.updateProgress(_currentUser!.id, QuestType.login, 1);
            
            // Basit bir snackbar veya animasyon
            // if (mounted) {
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     const SnackBar(
            //       content: Text('Günlük ödül alındı! 🎉'),
            //       backgroundColor: Colors.amber,
            //     ),
            //   );
            // }
          },
        ),
      );
    } else {
      // Ödül zaten alınmışsa bile günlük görev için login say
      // (Bunu her açılışta yapmak yerine sadece günde bir kez yapmak daha doğru olabilir ama şimdilik basit tutalım)
      // await _questService.updateProgress(_currentUser!.id, QuestType.login, 1);
    }
  }
  
  /// XP kazanım animasyonu göster
  void _showXPGainAnimation(XPGainResult result) {
    if (result.xpGained <= 0 || !mounted) return;
    
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.4,
        left: 0,
        right: 0,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 800),
          tween: Tween<double>(begin: 0, end: 1),
          onEnd: () {
            Future.delayed(const Duration(seconds: 2), () {
              entry.remove();
            });
          },
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.amber, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '+${result.xpGained} XP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    
    overlay.insert(entry);
  }
  
  /// Seviye atlama dialogu göster
  void _showLevelUpDialog(XPGainResult result) {
    if (!mounted || result.rewards == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(
        reward: result.rewards!,
      ),
    );
  }

  
  /// XP Kazandır (diğer entegrasyon noktaları için helper)
  Future<void> _awardXP(XPGainResult result) async {
    if (!result.hasGain || !mounted) return;
    
    // Kullanıcıyı yenile
    await _loadCurrentUser();
    
    // XP animasyonu göster
    _showXPGainAnimation(result);
    
    // Seviye atlandıysa dialog göster
    if (result.leveledUp) {
      await Future.delayed(const Duration(milliseconds: 1500));
      _showLevelUpDialog(result);
    }
  }
}

class WiggleBadge extends StatefulWidget {
  final Widget child;

  const WiggleBadge({Key? key, required this.child}) : super(key: key);

  @override
  State<WiggleBadge> createState() => _WiggleBadgeState();
}

class _WiggleBadgeState extends State<WiggleBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600), // 2 sallanma için süre
      vsync: this,
    );

    // Sallanma animasyonu: 0 -> -0.05 -> 0.05 -> -0.05 -> 0.05 -> 0
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Her 3 saniyede bir animasyonu tetikle
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

