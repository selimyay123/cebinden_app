import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../services/notification_service.dart';
import '../services/ad_service.dart';
import '../services/xp_service.dart';
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
import '../services/daily_login_service.dart';
import '../widgets/daily_login_dialog.dart';
import 'taxi_game_screen.dart';

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
  
  // Tutorial aktif mi? (scroll'u engellemek için)
  bool _isTutorialActive = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    // İlk reklam yükleme
    _adService.loadRewardedAd();
  }

  @override
  void dispose() {
    _adService.dispose();
    super.dispose();
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
      
      setState(() {
        _currentUser = user;
        _userVehicles = vehicles;
        _vehicleCount = vehicleCount;
        _userListedVehicles = listedVehicles;
        _pendingOffersCount = pendingOffers;
        _isLoading = false;
      });
      
      // Günlük giriş bonusunu (Streak) kontrol et
      _checkDailyStreak();
      
      // Günlük görevleri kontrol et/oluştur
      _questService.checkAndGenerateQuests(user.id);
      
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
              content: Text('ads.notReady'.tr()),
              backgroundColor: Colors.orange,
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
            title: Text('home.title'.tr()),
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
              : RefreshIndicator(
                  onRefresh: _loadCurrentUser,
                  child: SingleChildScrollView(
                    physics: _isTutorialActive 
                        ? const NeverScrollableScrollPhysics() // Tutorial sırasında scroll kapalı
                        : const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Profil ve Bakiye Kartı
                        _buildProfileCard(),
                        
                        // XP Progress Kartı ve Reklam İzle yan yana
                        _buildXPAndAdRow(),
                        
                        const SizedBox(height: 16),
                        
                        // Hızlı İşlemler
                        _buildQuickActions(),
                        
                        const SizedBox(height: 16),
                        
                        // Galeri Satın Al
                        // _buildBuyGalleryButton(),
                        
                        // const SizedBox(height: 16),
                        
                        // İstatistikler
                        _buildStatistics(),
                        
                        const SizedBox(height: 16),
                        
                        // Araçlarım (YORUM: Garaj özelliği için ayrı sayfa yapıldı)
                        // _buildMyVehicles(),
                        // const SizedBox(height: 16),
                        
                        // İlanlarım (YORUM: Quick actions'a taşındı)
                        // if (_userListedVehicles.isNotEmpty) ...[
                        //   _buildMyListings(),
                        //   const SizedBox(height: 16),
                        // ],
                        
                        // Son İşlemler veya Bilgilendirme
                        _buildRecentActivity(),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  // Profil ve Bakiye Kartı
  Widget _buildProfileCard() {
    if (_currentUser == null) return const SizedBox.shrink();
    
    final isProfit = _currentUser!.profitLossPercentage >= 0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.deepPurple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profil Resmi
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
              child: Text(
                _currentUser!.username[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Kullanıcı Bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kullanıcı Adı
                Text(
                  _currentUser!.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Toplam Para
                Text(
                  'home.balance'.tr(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  key: _balanceKey, // Tutorial için key
                  '${_formatCurrency(_currentUser!.balance)} ${'common.currency'.tr()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Altın ve Kar/Zarar
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Altın
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            // ${'store.gold'.tr()}
                            '${_currentUser!.gold.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Altın Al Butonu
                    InkWell(
                      onTap: () async {
                        // Mağaza sayfasına git
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StoreScreen(),
                          ),
                        );
                        // Sayfa kapanınca dashboard'u yenile (altın satın alınmış olabilir)
                        await _loadCurrentUser();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'store.buyGold'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // const Icon(
                            //   Icons.add,
                            //   color: Colors.white,
                            //   size: 14,
                            // ),
                          ],
                        ),
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // Kar/Zarar
                    // Container(
                    //   padding: const EdgeInsets.symmetric(
                    //     horizontal: 12,
                    //     vertical: 6,
                    //   ),
                    //   decoration: BoxDecoration(
                    //     color: isProfit 
                    //         ? Colors.green.withOpacity(0.2)
                    //         : Colors.red.withOpacity(0.2),
                    //     borderRadius: BorderRadius.circular(20),
                    //     border: Border.all(
                    //       color: isProfit ? Colors.green : Colors.red,
                    //       width: 1.5,
                    //     ),
                    //   ),
                    //   child: Row(
                    //     mainAxisSize: MainAxisSize.min,
                    //     children: [
                    //       Icon(
                    //         isProfit 
                    //             ? Icons.trending_up 
                    //             : Icons.trending_down,
                    //         color: isProfit ? Colors.green : Colors.red,
                    //         size: 18,
                    //       ),
                    //       const SizedBox(width: 6),
                    //       Text(
                    //         '${isProfit ? '+' : ''}${_currentUser!.profitLossPercentage.toStringAsFixed(2)}%',
                    //         style: TextStyle(
                    //           color: isProfit ? Colors.green : Colors.red,
                    //           fontSize: 14,
                    //           fontWeight: FontWeight.bold,
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // XP Progress Card - Mor kartın altında ayrı bir kart
  Widget _buildXPCard() {
    if (_currentUser == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seviye ve XP bilgisi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.amber, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Seviye ${_currentUser!.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentUser!.xp} XP',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(_currentUser!.levelProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress Bar
          Stack(
            children: [
              // Arka plan
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              // İlerleme
              FractionallySizedBox(
                widthFactor: _currentUser!.levelProgress,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.amber,
                        Colors.orange,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Sonraki seviye için gereken XP
          // Text(
          //   '${_currentUser!.xpToNextLevel} XP Sonraki seviyeye ${_currentUser!.level + 1}',
          //   style: TextStyle(
          //     color: Colors.grey[600],
          //     fontSize: 12,
          //   ),
          // ),
        ],
      ),
    );
  }
  
  // XP Kartı ve Reklam İzle alt alta
  Widget _buildXPAndAdRow() {
    if (_currentUser == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // XP Kartı (Tam genişlik)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seviye ve XP bilgisi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.amber, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.workspace_premium,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Seviye ${_currentUser!.level}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentUser!.xp} XP',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(_currentUser!.levelProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Progress Bar
                Stack(
                  children: [
                    // Arka plan
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    // İlerleme
                    FractionallySizedBox(
                      widthFactor: _currentUser!.levelProgress,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.amber,
                              Colors.orange,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                
                // Sonraki seviye için gereken XP
                // Text(
                //   '${_currentUser!.xpToNextLevel} XP Sonraki seviyeye ${_currentUser!.level + 1}',
                //   style: TextStyle(
                //     color: Colors.grey[600],
                //     fontSize: 10,
                //   ),
                // ),
              ],
            ),
          ),
          
          
          const SizedBox(height: 12),
          
          // Reklam İzle Butonu (Tam genişlik)
          InkWell(
            onTap: _watchRewardedAd,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Container(
                  //   padding: const EdgeInsets.all(10),
                  //   decoration: BoxDecoration(
                  //     color: Colors.amber.withOpacity(0.1),
                  //     shape: BoxShape.circle,
                  //   ),
                  //   child: const Icon(
                  //     Icons.play_circle_filled,
                  //     color: Colors.amber,
                  //     size: 26,
                  //   ),
                  // ),
                  const SizedBox(height: 8),
                  Text(
                    'Reklam izleyerek para kazan!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '5000 TL',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hızlı İşlemler
  Widget _buildQuickActions() {
    // Hızlı işlem butonları listesi - Yeni özellik eklemek için buraya ekleyin
    final quickActions = [
      {
        'icon': Icons.shopping_cart,
        'label': 'home.buyVehicle'.tr(),
        'color': Colors.blue,
        'onTap': () async {
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
      },
      {
        'icon': Icons.sell,
        'label': 'home.sellVehicle'.tr(),
        'color': Colors.orange,
        'onTap': () async {
          // Araç satış sayfasına git ve sonuç bekle
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
      },
      {
        'icon': Icons.garage,
        'label': 'home.myVehicles'.tr(),
        'color': Colors.green,
        'badge': _vehicleCount > 0 ? _vehicleCount : null, // Araç sayısı badge'i
        'onTap': () {
          // Kullanıcının satın aldığı araçları göster
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyVehiclesScreen(),
            ),
          );
        },
      },
      {
        'icon': Icons.store,
        'label': 'home.myListings'.tr(),
        'color': Colors.purple,
        'badge': _userListedVehicles.length > 0 ? _userListedVehicles.length : null, // İlan sayısı badge'i
        'onTap': () async {
          // İlanlar sayfasına git
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyListingsScreen(),
            ),
          );
          // Sayfa kapanınca dashboard'u yenile (ilan kaldırılmış olabilir)
          await _loadCurrentUser();
        },
      },
      {
        'icon': Icons.local_offer,
        'label': 'home.myOffers'.tr(),
        'color': Colors.teal,
        'badge': _pendingOffersCount > 0 ? _pendingOffersCount : null, // Badge ekledik
        'onTap': () async {
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
      },
      // NOT: Reklam İzle butonu artık XP kartının yanında
      {
        'icon': Icons.store,
        'label': 'store.title'.tr(),
        'color': Colors.deepOrange,
        'onTap': () async {
          // Mağaza sayfasına git
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StoreScreen(),
            ),
          );
          // Sayfa kapanınca dashboard'u yenile (altın bozdurulmuş olabilir)
          await _loadCurrentUser();
        },
      },
      {
        'icon': Icons.local_taxi,
        'label': 'Taksiye Çık',
        'color': Colors.amber,
        'onTap': () async {
          // Taksi oyununa git
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TaxiGameScreen(),
            ),
          );
          // Sayfa kapanınca dashboard'u yenile (para kazanılmış olabilir)
          await _loadCurrentUser();
        },
      },
      // {
      //   'icon': Icons.car_rental,
      //   'label': 'Araç Kirala',
      //   'color': Colors.purple,
      //   'onTap': () {
      //     // TODO: Araç kiralama sayfası
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(
      //         content: Text('Araç kiralama sayfası yakında...'),
      //         duration: Duration(seconds: 2),
      //       ),
      //     );
      //   },
      // },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 sütun
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5, // Buton yükseklik/genişlik oranı (daha alçak)
        ),
        itemCount: quickActions.length,
        itemBuilder: (context, index) {
          final action = quickActions[index];
          
          // Tutorial için key'leri atıyoruz
          Key? buttonKey;
          if (index == 0) {
            buttonKey = _marketButtonKey; // Araç Al butonu
          } else if (index == 1) {
            buttonKey = _sellVehicleButtonKey; // Araç Sat butonu
          } else if (index == 2) {
            buttonKey = _myVehiclesButtonKey; // Garajım butonu
          } else if (index == 4) {
            buttonKey = _offersButtonKey; // Teklifler butonu
          }
          // NOT: Reklam İzle artık XP kartının yanında, index'lerden çıkarıldı
          
          return _buildActionButton(
            key: buttonKey,
            icon: action['icon'] as IconData,
            label: action['label'] as String,
            color: action['color'] as Color,
            onTap: action['onTap'] as VoidCallback,
            badge: action['badge'] as int?,
            reward: action['reward'] as String?,
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    Key? key, // Tutorial için key parametresi
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int? badge, // Badge parametresi ekledik
    String? reward, // Ödül gösterimi için
  }) {
    return InkWell(
      key: key, // Key'i burada kullanıyoruz
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                // Badge
                if (badge != null && badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
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
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
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

  // İstatistikler
  Widget _buildStatistics() {
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
          Text(
            'home.statistics'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.directions_car,
                  label: 'home.totalVehicles'.tr(),
                  value: _vehicleCount.toString(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.local_offer,
                  label: 'home.pendingOffers'.tr(),
                  value: _pendingOffersCount.toString(),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.show_chart,
                  label: 'home.totalTransactions'.tr(),
                  value: _vehicleCount.toString(),
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
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
  Widget _buildBuyGalleryButton() {
    const galleryPrice = 10000000.0; // 10 Milyon TL

    return Container(
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
                colors: [Colors.green.shade700, Colors.green.shade500],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Sol taraf - İkon ve Başlık
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.store_mall_directory,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:                       Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'home.buyGallery'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'home.professionalBusiness'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Sağ taraf - Fiyat
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_formatCurrency(galleryPrice)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'TL',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.store_mall_directory,
                color: Colors.green,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Galeri Sahibi Olun',
                style: TextStyle(
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
              const Text(
                'Galeri satın alarak işletmenizi profesyonel seviyeye taşıyın ve yeni gelir kapıları açın.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              
              // Avantajlar
              const Text(
                'Galeri Avantajları',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.car_rental,
                title: 'home.rentalService'.tr(),
                description: 'Garajınızdaki araçları kiralayarak pasif gelir elde edin.',
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.trending_down,
                title: 'home.opportunityPurchases'.tr(),
                description: 'Acil nakit ihtiyacı olan müşterilerden piyasa değerinin altında araç satın alın.',
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.trending_up,
                title: 'home.highProfitMargin'.tr(),
                description: 'Profesyonel galeri olarak araçlarınızı daha yüksek fiyatlarla satın.',
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.workspace_premium,
                title: 'home.prestigeReputation'.tr(),
                description: 'Galeri statüsü ile daha fazla müşteri ve güven kazanın.',
              ),
              
              const SizedBox(height: 20),
              
              // Fiyat Bilgisi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Galeri Fiyatı:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${_formatCurrency(10000000.0)} ₺',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
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
            child: const Text(
              'İptal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Devam Et Butonu
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Galeri satın alma işlemi
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('home.galleryComingSoon'.tr()),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Devam Et',
              style: TextStyle(
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
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.green,
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

  // Son Aktivite / Bilgilendirme
  Widget _buildRecentActivity() {
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
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                'home.welcome'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'home.welcomeMessage'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          if (_currentUser != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Üyelik: ${_formatDate(_currentUser!.registeredAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
                      'İlanlarım',
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
                    '${_userListedVehicles.length} İlan',
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
                    '${_formatCurrency(vehicle.listingPrice ?? 0)} ₺',
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
                    'Aktif',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${vehicle.daysOwned} gün',
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
                      child: _currentUser != null
                          ? Text(
                              _currentUser!.username[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                              ),
                            )
                          : const Icon(Icons.person, size: 40),
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
                    icon: Icons.assignment,
                    title: 'Günlük Görevler',
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
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
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
    // ====== TEST MODU: Her açılışta tutorial göster ======
    // if (_currentUser != null && mounted) {
    //   await Future.delayed(const Duration(milliseconds: 800));
    //   _showTutorial();
    // }
    
    // ====== ASIL KOD (Test bitince aktif et) ======
    final prefs = await SharedPreferences.getInstance();
    final tutorialCompleted = prefs.getBool('tutorial_completed') ?? false;
    
    // Tutorial daha önce gösterilmediyse ve kullanıcı giriş yapmışsa göster
    if (!tutorialCompleted && _currentUser != null && mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      _showTutorial();
    }
  }

  /// Tutorial'ı tamamlandı olarak işaretle
  Future<void> _setTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);
  }

  /// Tutorial'ı göster
  void _showTutorial() {
    final targets = _createTutorialTargets();
    
    // Scroll'u engelle
    setState(() {
      _isTutorialActive = true;
    });
    
    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: false,
      textSkip: 'tutorial.skip'.tr(),
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      // Overlay'e (karanlık alana) tıklanmasını engelle
      onClickOverlay: (target) {
        // Hiçbir şey yapma, tıklama engellendi
      },
      onFinish: () {
        _setTutorialCompleted();
        // Scroll'u tekrar aktif et
        setState(() {
          _isTutorialActive = false;
        });
      },
      onSkip: () {
        _setTutorialCompleted();
        // Scroll'u tekrar aktif et
        setState(() {
          _isTutorialActive = false;
        });
        return true;
      },
    ).show(context: context);
  }

  /// Tutorial adımlarını oluştur
  List<TargetFocus> _createTutorialTargets() {
    return [
      // ADIM 1: Market Butonu (İlanlar)
      TargetFocus(
        identify: "market_button",
        keyTarget: _marketButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
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
                        '1/5',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_downward,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ADIM 2: Garajım Butonu
      TargetFocus(
        identify: "my_vehicles_button",
        keyTarget: _myVehiclesButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
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
                        '2/5',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ADIM 3: Araç Sat Butonu
      TargetFocus(
        identify: "sell_vehicle_button",
        keyTarget: _sellVehicleButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
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
                    'tutorial.step3_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tutorial.step3_desc'.tr(),
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
                        '3/5',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_downward,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ADIM 4: Teklifler Butonu
      TargetFocus(
        identify: "offers_button",
        keyTarget: _offersButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        contents: [
          TargetContent(
            align: ContentAlign.top, // Yukarıda göster (ekranın altında olduğu için)
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
                        '4/5',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_upward, // Ok yukarı göstermeli
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ADIM 5: Bakiye
      TargetFocus(
        identify: "balance",
        keyTarget: _balanceKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 15,
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
                        '5/5',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      Container(
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
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Günlük ödül alındı! 🎉'),
                  backgroundColor: Colors.amber,
                ),
              );
            }
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
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kutlama ikonu
            const Icon(
              Icons.celebration,
              size: 80,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              '🎉 ${'xp.levelUp'.tr()} 🎉',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Seviye ${result.newLevel}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            if (result.rewards != null) ...[
              const Divider(),
              Text(
                '${'xp.rewards'.tr()}:',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (result.rewards!.cashBonus > 0)
                Text(
                  '💰 ${_formatCurrency(result.rewards!.cashBonus)} ${'common.currency'.tr()}',
                  style: const TextStyle(fontSize: 18, color: Colors.green),
                ),
              if (result.rewards!.goldBonus > 0)
                Text(
                  '⭐ ${result.rewards!.goldBonus.toStringAsFixed(2)} ${'store.gold'.tr()}',
                  style: const TextStyle(fontSize: 18, color: Colors.amber),
                ),
              if (result.rewards!.unlocks.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...result.rewards!.unlocks.map((unlock) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '🔓 ${unlock.tr()}',
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'xp.awesome'.tr(),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
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

