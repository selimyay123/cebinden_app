import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../services/notification_service.dart';
import '../services/ad_service.dart';

import '../services/game_time_service.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';

// Doğrudan marka seçimi için
import 'opportunity_list_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import 'store_screen.dart';
import 'daily_quests_screen.dart';
import '../services/daily_quest_service.dart';
import '../models/daily_quest_model.dart';
import '../widgets/modern_alert_dialog.dart';
import '../widgets/custom_snackbar.dart';
import 'manage_staff_screen.dart';
import '../services/staff_service.dart';

import '../widgets/modern_button.dart';
import '../services/daily_login_service.dart';
import '../widgets/daily_login_dialog.dart';
import 'package:lottie/lottie.dart';
import 'skill_tree_screen.dart';
import '../services/rental_service.dart'; // Kiralama Servisi

import '../widgets/game_time_countdown.dart'; // 🆕 Game Time Countdown
import 'activity_screen.dart';
import 'leaderboard_screen.dart';
import '../services/leaderboard_service.dart';
import '../widgets/city_skyline_painter.dart';
import '../mixins/auto_refresh_mixin.dart';
import 'collection_screen.dart';
import '../services/market_refresh_service.dart';
import '../widgets/user_profile_avatar.dart';
import '../widgets/game_image.dart';

class HomeScreen extends StatefulWidget {
  final GlobalKey? marketTabKey;
  final GlobalKey? sellTabKey;
  final GlobalKey? garageTabKey;
  final GlobalKey? listingsTabKey;
  final GlobalKey? offersTabKey;
  final GlobalKey? storeTabKey;
  final GlobalKey<ScaffoldState>? mainScaffoldKey;

  const HomeScreen({
    super.key,
    this.marketTabKey,
    this.sellTabKey,
    this.garageTabKey,
    this.listingsTabKey,
    this.offersTabKey,
    this.storeTabKey,
    this.mainScaffoldKey,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, AutoRefreshMixin {
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  final AdService _adService = AdService();
  final NotificationService _notificationService = NotificationService();
  final DailyQuestService _questService = DailyQuestService();
  final DailyLoginService _loginService = DailyLoginService();
  final GameTimeService _gameTime = GameTimeService();
  final RentalService _rentalService = RentalService();
  final MarketRefreshService _marketService = MarketRefreshService();
  User? _currentUser;
  bool _isLoading = true;
  // Bekleyen teklif sayısı
  int _collectedCount = 0;
  int _totalCollectionCount = 0;
  int _vehicleCount = 0;
  List<UserVehicle> _userVehicles = [];
  List<UserVehicle> _userListedVehicles = []; // Satışa çıkarılan araçlar
  List<DailyQuest> _dailyQuests = []; // Günlük görevler

  // Tutorial için GlobalKey'ler
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _gameTimeKey = GlobalKey();
  final GlobalKey _questsCardKey = GlobalKey();
  final GlobalKey _collectionCardKey = GlobalKey();
  final GlobalKey _buyGalleryButtonKey = GlobalKey();
  final GlobalKey _taxiGameButtonKey = GlobalKey();

  // Kiralama geliri animasyonu için
  double _lastRentalIncome = 0.0;
  bool _showRentalIncomeAnimation = false;

  // Fire animasyonu için
  // Fire animasyonu için
  bool _showFireAnimation = false;

  // Tutorial aktif mi? (scroll'u engellemek için)
  bool _isTutorialActive = false;

  // Günlük ödül dialogu açık mı?
  bool _isDailyLoginDialogShown = false;

  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _userUpdateSubscription;
  StreamSubscription? _staffEventSubscription;

  @override
  int? get tabIndex => 3; // MainScreen'deki index

  @override
  void refresh() {
    _loadCurrentUser();
  }

  @override
  void initState() {
    super.initState();
    _initData();
    // İlk reklam yükleme
    _adService.loadRewardedAd();

    // Gün değişimini dinle
    _gameTime.addDayChangeListener(_onGameDayChanged);

    // Kullanıcı güncellemelerini dinle (Skill unlock, bakiye değişimi vb.)
    _userUpdateSubscription = _db.onUserUpdate.listen((_) {
      if (mounted) _loadCurrentUser();
    });

    // Personel Simülasyon Dinleyicisi (Global Bildirim)
    final staffService = StaffService(); // Singleton
    staffService.startSimulation(); // App açıldığında çalışmaya başlasın

    _staffEventSubscription = staffService.eventStream.listen((event) {
      if (mounted) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(event),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        // Bakiyeyi güncelle
        _loadCurrentUser();
      }
    });
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
    _userUpdateSubscription?.cancel();
    _staffEventSubscription?.cancel();
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
      await _rentalService.processDailyRental(_currentUser!.id);
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

      // Günlük kar/zarar sıfırlama kontrolü
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Günlük görevleri yükle
      final quests = await _questService.checkAndGenerateQuests(user.id);

      // Koleksiyon verilerini hesapla
      final allModels = _marketService.modelsByBrand;
      int totalModels = 0;
      allModels.forEach((key, value) {
        totalModels += value.length;
      });

      final ownedModelKeys = await _db.getOwnedModelKeys(user.id);
      final collectedCount = ownedModelKeys.length;

      if (mounted) {
        setState(() {
          _currentUser = user;
          _userVehicles = vehicles;
          _userListedVehicles = listedVehicles;
          _vehicleCount = vehicleCount;
          _dailyQuests = quests;
          _collectedCount = collectedCount;
          _totalCollectionCount = totalModels;
          _isLoading = false;
        });
      }

      User updatedUser = user;

      // Eğer son sıfırlama tarihi bugün değilse (veya null ise), sıfırla
      if (user.lastDailyResetDate == null ||
          DateTime(
                user.lastDailyResetDate!.year,
                user.lastDailyResetDate!.month,
                user.lastDailyResetDate!.day,
              ) !=
              today) {
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
              builder: (context) => ModernAlertDialog(
                title: '${'ads.rewardReceived'.tr()}',
                icon: Icons.attach_money,
                iconColor: Colors.greenAccent,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+5000 TL',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ads.rewardMessage'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                buttonText: 'common.ok'.tr(),
                onPressed: () => Navigator.pop(context),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text('ads.notReady'.tr()),
              backgroundColor: Colors.orange.withValues(alpha: 0.8),
              duration: const Duration(seconds: 2),
            ),
          );
          // Yeni reklam yükle
          _adService.loadRewardedAd();
        }
      },
    );
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
                        future: NotificationService().getUnreadCount(
                          _currentUser!.id,
                        ),
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
              // IconButton(
              //   icon: const Icon(Icons.logout),
              //   tooltip: 'auth.logout'.tr(),
              //   onPressed: _logout,
              // ),
            ],
          ),
          drawer: _buildDrawer(context),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  decoration: BoxDecoration(
                    image: GameDecorationImage(
                      assetPath: 'assets/images/home_bg.png',
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

                                  // 🆕 Reklam ve Sayaç (Yan Yana)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        // Reklam Kartı
                                        Expanded(child: _buildWatchAdCard()),
                                        const SizedBox(width: 12),
                                        // Oyun Zamanı Sayacı
                                        Expanded(
                                          child: GameTimeCountdown(
                                            key: _gameTimeKey,
                                            margin: EdgeInsets.zero,
                                            currentUser: _currentUser,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Günlük Görevler ve Koleksiyon (Yan Yana)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _buildDailyQuestsCard(),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildCollectionCard()),
                                      ],
                                    ),
                                  ),

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
                                  // Galeri Satın Al (sadece galeri sahibi değilse göster)
                                  if (_currentUser != null &&
                                      !_currentUser!.ownsGallery)
                                    _buildBuyGalleryButton(),

                                  if (_currentUser != null &&
                                      !_currentUser!.ownsGallery)
                                    const SizedBox(height: 16),

                                  // Galerim (sadece galeri sahibiyse göster)
                                  if (_currentUser != null &&
                                      _currentUser!.ownsGallery)
                                    _buildMyGallerySection(),

                                  if (_currentUser != null &&
                                      _currentUser!.ownsGallery)
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
        color: Colors.white.withValues(
          alpha: 0.2,
        ), // Blur yerine yüksek opaklıkta beyaz
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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

    final rankColor = _getRankColor(_currentUser!.level);

    // RepaintBoundary ile sarmalayarak gereksiz yeniden çizmeleri önlüyoruz
    return RepaintBoundary(
      child: Container(
        key: _balanceKey,
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.withValues(alpha: 0.6),
              Colors.deepPurple.shade400.withValues(alpha: 0.6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.5),
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
                    color: Colors.black.withValues(alpha: 0.15),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profil Resmi ve Bilgiler (Yan Yana ve Ortalı)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Profil Resmi ve Çerçeve
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(
                                  highlightProfilePicture: true,
                                ),
                              ),
                            ).then(
                              (_) => _loadCurrentUser(),
                            ); // Geri dönünce refresh et
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow Efekti
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: rankColor.withValues(alpha: 0.5),
                                      blurRadius: 15,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              // Çerçeve
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      rankColor,
                                      rankColor.withValues(alpha: 0.5),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    2.5,
                                  ), // Çerçeve kalınlığı
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: UserProfileAvatar(
                                      imageUrl: _currentUser?.profileImageUrl,
                                      username: _currentUser?.username,
                                      radius: 35,
                                      fontSize: 32,
                                    ),
                                  ),
                                ),
                              ),

                              // Düzenleme İkonu (Sağ Üst)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Tooltip(
                                  message: 'settings.changeProfilePicture'.tr(),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.deepPurple.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.deepPurple.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              // Seviye Rozeti (Avatarın altında)
                              Positioned(
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: rankColor,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Lv. ${_currentUser!.level}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Kullanıcı Bilgileri
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kullanıcı Adı
                            Text(
                              _currentUser!.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: rankColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getRankTitle(
                                  _currentUser!.level,
                                ).toUpperCase(),
                                style: TextStyle(
                                  color: rankColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Toplam Para (Animasyonlu)
                    Text(
                      'home.balance'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Görünmez Text ile alan rezerve et (Titremeyi önler)
                              Text(
                                '${_formatCurrency(_currentUser!.balance)} ${'common.currency'.tr()}',
                                style: const TextStyle(
                                  color: Colors.transparent, // Görünmez
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              // Animasyonlu Değer
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin:
                                      _currentUser!.balance -
                                      (_showRentalIncomeAnimation
                                          ? _lastRentalIncome
                                          : 0),
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
                            ],
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
                                      offset: Offset(
                                        0,
                                        20 * (1 - value),
                                      ), // Aşağıdan yukarı kayma
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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

                    const SizedBox(height: 2),

                    // Kar/Zarar Göstergesi
                    Builder(
                      builder: (context) {
                        // Günlük kar/zarar hesabı
                        final dailyStartingBalance =
                            _currentUser!.dailyStartingBalance;
                        final currentBalance = _currentUser!.balance;
                        final dailyProfit =
                            currentBalance - dailyStartingBalance;

                        // Yüzdelik hesaplarken küsüratı at (User request)
                        // Örn: 346.702.29 -> 346702 üzerinden yüzde hesapla
                        final dailyProfitInt = dailyProfit.truncateToDouble();

                        double percentage = 0.0;
                        if (dailyStartingBalance > 0) {
                          percentage =
                              (dailyProfitInt / dailyStartingBalance) * 100;
                        }

                        final isProfit = dailyProfit >= 0;
                        final profitColor = isProfit
                            ? Colors.greenAccent
                            : Colors.redAccent;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isProfit
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: profitColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '%${percentage.abs().toStringAsFixed(1)} (${_formatCurrency(dailyProfit)})',
                                style: TextStyle(
                                  color: profitColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

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
                        const SizedBox(height: 2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _currentUser!.levelProgress,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.amber,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_currentUser!.isXpBoostActive)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'X2',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Text(
                                '${_currentUser!.xp} XP',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Yetenek Ağacı Butonu
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SkillTreeScreen(),
                          ),
                        ).then((_) => _loadCurrentUser());
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'home.tasks'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (_currentUser != null &&
                                _currentUser!.skillPoints > 0) ...[
                              const SizedBox(width: 8),
                              PulseBadge(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _currentUser!.skillPoints.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Altın Al Butonu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mevcut Altın
                        Container(
                          width: 120,
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _currentUser!.gold.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Altın Al Butonu
                        // Altın Al Butonu
                        ModernButton(
                          text: 'home.buyGold'.tr(),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StoreScreen(),
                              ),
                            );
                          },
                          color: Colors.amber,
                          textColor: Colors.deepPurple,
                          gradientColors: [Colors.amber, Colors.amber.shade700],
                          height: 40,
                          width: 120,
                          isFullWidth: false,
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
      height: 90, // Sayaç ile tam uyum için hafifçe artırıldı
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
                    Colors.deepPurple.shade700.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Sol Taraf - Chest Animasyonu
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: Lottie.asset(
                        'assets/animations/ad_chest.json',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Orta Kısım - Yazılar
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'common.ads.freeMoney'.tr(),
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'home.watchAd'.tr().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // FREE Badge (Sağ Üst Köşe)
          Positioned(
            top: -6,
            right: -6,
            child: WiggleBadge(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.redAccent, Colors.red],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'common.free'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
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
  // Günlük Görevler Kartı
  Widget _buildDailyQuestsCard() {
    if (_dailyQuests.isEmpty) return const SizedBox.shrink();

    final completedCount = _dailyQuests.where((q) => q.isCompleted).length;

    final totalCount = _dailyQuests.length;
    final hasRewardsToClaim = _dailyQuests.any(
      (q) => q.isCompleted && !q.isClaimed,
    );

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DailyQuestsScreen()),
        );
        _loadCurrentUser(); // Geri dönünce yenile
      },
      child: SizedBox(
        key: _questsCardKey,
        height: 100, // Sabit yükseklik
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık (Üstte)
              Text(
                'quests.title'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Biraz küçülttük
                ),
              ),

              const Spacer(), // Aradaki boşluğu doldur
              // Alt Kısım (İkon ve İstatistik)
              Row(
                children: [
                  // İkon
                  Container(
                    padding: const EdgeInsets.all(8), // Padding azaltıldı
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: Colors.blue,
                      size: 20, // İkon küçültüldü
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Metinler
                  // Metinler
                  Expanded(
                    child: hasRewardsToClaim
                        ? PulseBadge(
                            child: Text(
                              '$completedCount/$totalCount',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Text(
                            '$completedCount/$totalCount',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),

                  // Sağ taraf (Badge veya Ok)
                  if (hasRewardsToClaim)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Koleksiyon Kartı
  Widget _buildCollectionCard() {
    if (_currentUser == null) return const SizedBox.shrink();

    return GestureDetector(
      key: _collectionCardKey,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CollectionScreen()),
        ).then((_) => _loadCurrentUser());
      },
      child: _buildGlassContainer(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.collections_bookmark,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'home.collection'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // İlerleme Çubuğu ve Metin
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_collectedCount / $_totalCollectionCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    Text(
                      '%${(_totalCollectionCount > 0 ? (_collectedCount / _totalCollectionCount * 100).toInt() : 0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalCollectionCount > 0
                        ? _collectedCount / _totalCollectionCount
                        : 0,
                    backgroundColor: Colors.purple.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.purple.shade400,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
        delegate: SliverChildBuilderDelegate((context, index) {
          // Tutorial için key'leri atıyoruz
          Key? buttonKey;
          final label = quickActions[index]['label'] as String;

          if (label == 'home.taxi'.tr()) {
            buttonKey = _taxiGameButtonKey;
          }

          return _buildActionButton(
            key: buttonKey,
            icon: quickActions[index]['icon'] as IconData?,
            imagePath: quickActions[index]['imagePath'] as String?,
            label: label,
            color: quickActions[index]['color'] as Color,
            onTap: quickActions[index]['onTap'] as VoidCallback,
            badge: quickActions[index]['badge'] as int?,
            reward: quickActions[index]['reward'] as String?,
            animationPath: quickActions[index]['animationPath'] as String?,
            showAnimation:
                quickActions[index]['showAnimation'] as bool? ?? false,
          );
        }, childCount: quickActions.length),
      ),
    );
  }

  // Hızlı İşlemler Listesi
  List<Map<String, dynamic>> _getQuickActions() {
    return [
      /*
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
                categoryColor: Colors.deepPurple,
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
      */

      /*
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
      */
      /*
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
      */
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
        padding: EdgeInsets
            .zero, // Padding'i kaldırdık, içeriği kendimiz yöneteceğiz
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
                      padding: imagePath != null
                          ? EdgeInsets.zero
                          : const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: imagePath != null
                            ? Colors.transparent
                            : color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: imagePath != null
                          ? Image.asset(
                              imagePath,
                              width: 80,
                              height: 80,
                              fit: BoxFit.contain,
                            )
                          : Icon(icon, color: color, size: 28),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(
                      alpha: 0.8,
                    ), // Koyu mor renk (Reklam kartı ile uyumlu)
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    label
                        .toUpperCase()
                        .split(' ')
                        .first, // Sadece ilk kelimeyi alıp BÜYÜK HARF yapıyoruz
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
                  color: Colors.amber.withValues(alpha: 0.2),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                            categoryColor: Colors.deepPurple,
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
                          color: Colors.deepPurple.withValues(alpha: 0.1),
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
            key: _buyGalleryButtonKey,
            onTap: () => _showGalleryInfoDialog(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade800,
                    Colors.deepPurple.shade600,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.5),
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
                          painter: CitySkylinePainter(color: Colors.black),
                        ),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      // Sol taraf - Animasyon
                      Lottie.asset(
                        'assets/animations/gallery_v2.json',
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
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
                                fontSize: 18,
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
                            const SizedBox(height: 2),
                            Text(
                              'home.professionalBusiness'.tr(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Fiyat Etiketi
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
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
                                  fontSize: 11,
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
                          color: Colors.white.withValues(alpha: 0.1),
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
      ),
    );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          content: Text('home.galleryInsufficientFunds'.tr()),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'home.buyGallery'.tr(),
        content: Text(
          'home.galleryPrice'.tr() +
              ': ${_formatCurrency(galleryPrice)} TL\n\n' +
              'common.continue'.tr() +
              '?',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        buttonText: 'common.continue'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.store_mall_directory,
        iconColor: Colors.deepPurple,
      ),
    );

    if (confirmed != true) return;

    // Satın alma işlemi
    final newBalance = _currentUser!.balance - galleryPrice;
    final updatedUser = _currentUser!.copyWith(
      balance: newBalance,
      ownsGallery: true,
      galleryPurchaseDate: DateTime.now(),
      garageLimit:
          _currentUser!.garageLimit + 5, // Galeri satın alımında +5 araç limiti
    );

    await _db.updateUser(_currentUser!.id, updatedUser.toJson());

    // UI'ı güncelle
    await _loadCurrentUser();

    if (!mounted) return;

    // Başarı mesajı
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'home.galleryPurchaseSuccess'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.store_mall_directory,
              size: 80,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 16),
            Text(
              'home.galleryDescription'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.white),
            ),
          ],
        ),
        buttonText: 'common.ok'.tr(),
        onPressed: () => Navigator.pop(context),
        icon: Icons.celebration,
        iconColor: Colors.green,
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
          colors: [
            Colors.deepPurple.shade700.withValues(alpha: 0.7),
            Colors.deepPurple.shade500.withValues(alpha: 0.7),
          ],
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
                'assets/animations/gallery_v2.json',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 16),
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

          const SizedBox(height: 5),

          // Kiraya Ver Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showRentOutDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.withValues(alpha: 0.5)),
                ),
                elevation: 0,
              ),
              child: Text(
                'gallery.rentOut'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Fırsat Alımları Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OpportunityListScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.purple.withValues(alpha: 0.5)),
                ),
                elevation: 0,
              ),
              child: Text(
                'home.opportunityPurchases'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 🆕 Personel Yönetimi Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageStaffScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.people_outline, size: 20),
              label: Text(
                'staff.manage_staff'.tr(defaultValue: 'Personel Yönetimi'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.5)),
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
    final rentedVehicles = _userVehicles
        .where((v) => v.isRented || v.canCollectRentalIncome)
        .toList();

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
            final dailyIncome =
                vehicle.purchasePrice * RentalService.dailyRentalRate;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Sol: Araç Adı
                  Expanded(
                    flex: 3,
                    child: Text(
                      vehicle.brand,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                    ),
                  ),

                  // Orta: Gelir
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Text(
                        vehicle.isRented
                            ? '+${_formatCurrency(dailyIncome)} TL'
                            : '+${_formatCurrency(vehicle.pendingRentalIncome)} TL',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // Sağ: Buton
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: vehicle.canCollectRentalIncome
                              ? () async {
                                  final incomeToCollect =
                                      vehicle.pendingRentalIncome;
                                  final success = await _rentalService
                                      .collectRentalIncome(
                                        _currentUser!.id,
                                        vehicle.id,
                                      );
                                  if (success && mounted) {
                                    // Kiralama geliri animasyonunu tetikle
                                    setState(() {
                                      _lastRentalIncome = incomeToCollect;
                                      _showRentalIncomeAnimation = true;
                                    });

                                    // 3 saniye sonra animasyonu gizle
                                    Future.delayed(
                                      const Duration(seconds: 3),
                                      () {
                                        if (mounted) {
                                          setState(() {
                                            _showRentalIncomeAnimation = false;
                                          });
                                        }
                                      },
                                    );

                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        CustomSnackBar(
                                          content: Text(
                                            'gallery.incomeCollected'.tr(),
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      _loadCurrentUser(); // Listeyi yenile
                                    }
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.withValues(
                              alpha: 0.7,
                            ),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'gallery.collectIncome'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
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
    final rentableVehicles = await _rentalService.getRentableVehicles(
      _currentUser!.id,
    );

    if (!mounted) return;

    if (rentableVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        CustomSnackBar(
          content: Text('gallery.noRentableVehicles'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Şu an kirada olan araç sayısını hesapla
    final currentRentedCount = _userVehicles.where((v) => v.isRented).length;
    final remainingSlots = 3 - currentRentedCount;

    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        CustomSnackBar(
          content: Text('gallery.rentLimitReached'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Seçilen araçları tutmak için set
    final selectedVehicleIds = <String>{};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sbContext, setState) => ModernAlertDialog(
          title:
              '${'gallery.rentOutTitle'.tr()} ($remainingSlots ${'gallery.slotsLeft'.tr()})',
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rentableVehicles.length,
              itemBuilder: (context, index) {
                final vehicle = rentableVehicles[index];
                final dailyIncome =
                    vehicle.purchasePrice * RentalService.dailyRentalRate;
                final isSelected = selectedVehicleIds.contains(vehicle.id);
                // Eğer seçim hakkı dolduysa ve bu araç seçili değilse, disable et
                final isDisabled =
                    !isSelected && selectedVehicleIds.length >= remainingSlots;

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: isDisabled
                      ? null
                      : (bool? value) {
                          setState(() {
                            if (value == true) {
                              if (selectedVehicleIds.length < remainingSlots) {
                                selectedVehicleIds.add(vehicle.id);
                              }
                            } else {
                              selectedVehicleIds.remove(vehicle.id);
                            }
                          });
                        },
                  title: Text(
                    vehicle.fullName.replaceAll(
                      'Serisi',
                      'vehicles.series'.tr(),
                    ),
                    style: TextStyle(
                      color: isDisabled ? Colors.white38 : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '${'gallery.dailyIncome'.tr()}: ${_formatCurrency(dailyIncome)} TL',
                    style: TextStyle(
                      color: isDisabled ? Colors.white30 : Colors.greenAccent,
                    ),
                  ),
                  secondary: Icon(
                    Icons.car_rental,
                    color: isDisabled ? Colors.white30 : Colors.white70,
                  ),
                  activeColor: Colors.deepPurpleAccent,
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: isDisabled ? Colors.white30 : Colors.white54,
                  ),
                );
              },
            ),
          ),
          buttonText: 'gallery.rentOut'.tr(),
          onPressed: selectedVehicleIds.isEmpty
              ? null
              : () async {
                  Navigator.pop(dialogContext);

                  // Seçilen araçları kiraya ver
                  for (final vehicleId in selectedVehicleIds) {
                    await _rentalService.rentVehicle(vehicleId);
                  }

                  // Başarı mesajı
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      CustomSnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(child: Text('gallery.rentSuccess'.tr())),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }

                  // Ekranı yenile
                  _loadCurrentUser();
                },
          secondaryButtonText: 'common.cancel'.tr(),
          onSecondaryPressed: () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }

  // Galeri Avantaj Item
  Widget _buildGalleryBenefit({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
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
        Icon(Icons.check_circle, color: Colors.white, size: 16),
      ],
    );
  }

  // Galeri Bilgilendirme Dialog'u
  void _showGalleryInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'home.galleryAdvantages'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGalleryBenefit(
              icon: Icons.key,
              title: 'home.advantage1Title'.tr(),
            ),
            const SizedBox(height: 12),
            _buildGalleryBenefit(
              icon: Icons.local_offer,
              title: 'home.advantage2Title'.tr(),
            ),
            const SizedBox(height: 12),
            _buildGalleryBenefit(
              icon: Icons.trending_up,
              title: 'home.advantage3Title'.tr(),
            ),
            const SizedBox(height: 12),
            _buildGalleryBenefit(
              icon: Icons.verified,
              title: 'home.advantage4Title'.tr(),
            ),
            const SizedBox(height: 12),
            _buildGalleryBenefit(
              icon: Icons.garage,
              title: 'home.advantage5Title'.tr(),
            ),
            const SizedBox(height: 20),

            // Fiyat Bilgisi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: 0.3),
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
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        buttonText: 'common.continue'.tr(),
        onPressed: () {
          Navigator.pop(context);
          _purchaseGallery();
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  // İlan kartı

  // Para formatı
  String _formatCurrency(double amount) {
    return amount
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  // Drawer (Yan Menü)
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white.withValues(alpha: 0.2),
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
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: UserProfileAvatar(
                      imageUrl: _currentUser?.profileImageUrl,
                      username: _currentUser?.username,
                      radius: 36,
                      fontSize: 32,
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
                        color: Colors.white.withValues(alpha: 0.9),
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
                    icon: Icons.psychology,
                    title: 'home.tasks'.tr(),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SkillTreeScreen(),
                        ),
                      );
                      await _loadCurrentUser();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.collections,
                    title: 'drawer.collection'.tr(),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CollectionScreen(),
                        ),
                      );
                    },
                  ),

                  /*
                  _buildDrawerItem(
                    icon: Icons.shopping_cart,
                    title: 'drawer.buyVehicle'.tr(),
                    onTap: () async {
                      Navigator.pop(context); // Drawer'ı kapat
                      
                      // Doğrudan marka seçim sayfasına git (Otomobil kategorisi)
                      final purchased = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrandSelectionScreen(
                            categoryName: 'vehicles.categoryAuto'.tr(), // Otomobil kategorisi
                            categoryColor: Colors.deepPurple,
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
                      await _loadCurrentUser();
                    },
                  ),
                  */
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
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
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
      selectedTileColor: Colors.deepPurple.withValues(alpha: 0.1),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
      _scrollController
          .animateTo(
            0.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (!mounted) return;
            if (!mounted) return;
            _startTutorialSequence();
          });
    } else {
      _startTutorialSequence();
    }
  }

  void _startTutorialSequence() {
    // Bottom Navigation Bar Tutorial
    TutorialCoachMark(
      targets: _createTutorialTargets(),
      colorShadow: Colors.black,
      textSkip: "tutorial.skip".tr(),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        _setTutorialCompleted();
        setState(() {
          _isTutorialActive = false;
        });
      },
      onClickTarget: (target) {},
      onClickOverlay: (target) {},
      onSkip: () {
        _setTutorialCompleted();
        setState(() {
          _isTutorialActive = false;
        });
        return true;
      },
    ).show(context: widget.mainScaffoldKey?.currentContext ?? context);
  }

  /// Tutorial Targets (Bottom Navigation Bar)
  List<TargetFocus> _createTutorialTargets() {
    return [
      // ADIM 1: Market
      TargetFocus(
        identify: "market_tab",
        keyTarget: widget.marketTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        radius: 30,
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
                    'tutorial.market_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.market_desc'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '1/6',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 2: Araç Sat
      TargetFocus(
        identify: "sell_tab",
        keyTarget: widget.sellTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        radius: 30,
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
                    'tutorial.sell_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.sell_desc'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '2/6',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 3: Garajım
      TargetFocus(
        identify: "garage_tab",
        keyTarget: widget.garageTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        radius: 30,
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
                    'tutorial.garage_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.garage_desc'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '3/6',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 4: İlanlarım
      TargetFocus(
        identify: "listings_tab",
        keyTarget: widget.listingsTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        radius: 30,
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
                    'tutorial.listings_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.listings_desc'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '4/6',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 5: Teklifler
      TargetFocus(
        identify: "offers_tab",
        keyTarget: widget.offersTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        radius: 30,
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
                    'tutorial.offers_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.offers_desc'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '5/6',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ADIM 6: Mağaza
      TargetFocus(
        identify: "store_tab",
        keyTarget: widget.storeTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        radius: 30,
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
                    'tutorial.store_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.store_desc'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '6/6',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
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
                            border: Border.all(color: Colors.white, width: 1),
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

    // Eğer ödül alınabilirse ve dialog zaten açık değilse dialog göster
    if (status['canClaim'] == true && mounted && !_isDailyLoginDialogShown) {
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

      if (!mounted || _isDailyLoginDialogShown) return;

      _isDailyLoginDialogShown = true;

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
            await _questService.updateProgress(
              _currentUser!.id,
              QuestType.login,
              1,
            );

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
      ).then((_) {
        if (mounted) {
          _isDailyLoginDialogShown = false;
        }
      });
    } else {
      // Ödül zaten alınmışsa bile günlük görev için login say
      // (Bunu her açılışta yapmak yerine sadece günde bir kez yapmak daha doğru olabilir ama şimdilik basit tutalım)
      // await _questService.updateProgress(_currentUser!.id, QuestType.login, 1);
    }
  }

  /// XP kazanım animasyonu göster

  /// Seviye atlama dialogu göster

  /// XP Kazandır (diğer entegrasyon noktaları için helper)
}

class WiggleBadge extends StatefulWidget {
  final Widget child;

  const WiggleBadge({Key? key, required this.child}) : super(key: key);

  @override
  State<WiggleBadge> createState() => _WiggleBadgeState();
}

class _WiggleBadgeState extends State<WiggleBadge>
    with SingleTickerProviderStateMixin {
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
        return Transform.rotate(angle: _animation.value, child: child);
      },
      child: widget.child,
    );
  }
}

class PulseBadge extends StatefulWidget {
  final Widget child;
  const PulseBadge({Key? key, required this.child}) : super(key: key);

  @override
  State<PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<PulseBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}
