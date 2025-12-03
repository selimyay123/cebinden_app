import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import '../models/vehicle_model.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import '../models/offer_model.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/offer_service.dart';
import '../services/favorite_service.dart';
import '../services/localization_service.dart';
import '../services/xp_service.dart';
import '../services/daily_quest_service.dart';
import '../models/daily_quest_model.dart';
import '../services/skill_service.dart'; // Yetenek Servisi
import '../services/skill_service.dart'; // Yetenek Servisi
import '../services/market_refresh_service.dart'; // Market Servisi (Fiyat hesaplama için)
import '../widgets/vehicle_top_view.dart';
import 'my_offers_screen.dart';
import 'my_vehicles_screen.dart';
import 'package:intl/intl.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ConfettiController _confettiController;
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  final OfferService _offerService = OfferService();
  final FavoriteService _favoriteService = FavoriteService();
  final XPService _xpService = XPService();
  final DailyQuestService _questService = DailyQuestService();
  final MarketRefreshService _marketService = MarketRefreshService();
  User? _currentUser;
  bool _isFavorite = false;
  late Vehicle _vehicle;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
    _tabController = TabController(length: 2, vsync: this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      // Favori durumunu kontrol et
      final isFavorite = _favoriteService.isFavorite(user.id, _vehicle.id);
      setState(() {
        _currentUser = user;
        _isFavorite = isFavorite;
      });
    }
  }

  /// Favori durumunu değiştir
  Future<void> _toggleFavorite() async {
    if (_currentUser == null) return;

    if (_isFavorite) {
      // Favoriden kaldır
      final success = await _favoriteService.removeFavorite(_currentUser!.id, _vehicle.id);
      if (success) {
        setState(() {
          _isFavorite = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('favorites.removedFromFavorites'.tr()),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // Favorilere ekle
      final success = await _favoriteService.addFavorite(_currentUser!.id, _vehicle);
      if (success) {
        setState(() {
          _isFavorite = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('favorites.addedToFavorites'.tr()),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        return Stack(
          children: [
            Scaffold(
              body: CustomScrollView(
        slivers: [
          // Resim ve AppBar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.deepPurple,
            actions: [
              // Favori Butonu
              if (_currentUser != null)
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleFavorite,
                  tooltip: _isFavorite 
                      ? 'favorites.removeFromFavorites'.tr() 
                      : 'favorites.addToFavorites'.tr(),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.grey[300],
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Placeholder Resim (Icon)
                    Icon(
                      Icons.directions_car,
                      size: 120,
                      color: Colors.grey[400],
                    ),
                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // İçerik
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık ve Fiyat
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _vehicle.fullName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _vehicle.location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'vehicles.price'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            _buildPriceDisplay(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.deepPurple,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.deepPurple,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: 'vehicles.listingInfo'.tr()),
                      Tab(text: 'vehicles.description'.tr()),
                    ],
                  ),
                ),

                // Tab Content - Dinamik yükseklik
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    return _tabController.index == 0
                        ? _buildSpecificationsTab()
                        : _buildDescriptionTab();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Teklif Ver Butonu
              Expanded(
                child: OutlinedButton(
                  onPressed: _currentUser != null ? () => _showMakeOfferDialog() : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.deepPurple, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'purchase.makeOffer'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Satın Al Butonu
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentUser != null ? () => _showPurchaseDialog() : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'purchase.title'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        ),
        // Confetti Overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.red,
              Colors.yellow,
            ],
            numberOfParticles: 30,
            gravity: 0.3,
          ),
        ),
      ],
    );
      },
    );
  }

  Widget _buildPriceDisplay() {
    if (_currentUser == null) {
      return Text(
        '${_formatCurrency(widget.vehicle.price)} TL',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      );
    }

    // Ekspertiz sonrası fiyat değişimi kontrolü
    // Eğer ekspertiz yapıldıysa ve fiyat düştüyse, eski fiyatı çizili göster
    final bool priceDropped = _vehicle.isExpertiseDone && _vehicle.price < _vehicle.declaredPrice;
    
    // Yetenek indirimi
    final multiplier = SkillService.getBuyingMultiplier(_currentUser!);
    final discountedPrice = _vehicle.price * multiplier;
    final hasSkillDiscount = multiplier < 1.0;

    if (!priceDropped && !hasSkillDiscount) {
      // Hiçbir indirim yok
      return Text(
        '${_formatCurrency(_vehicle.price)} TL',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 1. Ekspertiz öncesi fiyat (Eğer düştüyse)
        if (priceDropped)
          Text(
            '${_formatCurrency(_vehicle.declaredPrice)} TL',
            style: TextStyle(
              fontSize: 14,
              decoration: TextDecoration.lineThrough,
              color: Colors.red[300],
              fontWeight: FontWeight.bold,
            ),
          ),
          
        // 2. Güncel Liste Fiyatı (Eğer yetenek indirimi varsa çizili, yoksa normal)
        if (hasSkillDiscount) ...[
          Text(
            '${_formatCurrency(_vehicle.price)} TL',
            style: TextStyle(
              fontSize: priceDropped ? 14 : 16, // Eğer üstte çizili varsa bunu da küçük yap
              decoration: TextDecoration.lineThrough,
              color: Colors.grey[600],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '-%${((1 - multiplier) * 100).toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatCurrency(discountedPrice)} TL',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ] else ...[
          // Sadece ekspertiz indirimi var, yetenek indirimi yok
          Text(
            '${_formatCurrency(_vehicle.price)} TL',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green, // Fiyat düştüğü için yeşil
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showPurchaseDialog() async {
    if (_currentUser == null) return;

    final currentBalance = _currentUser!.balance;
    // Yetenek indirimi uygula
    final multiplier = SkillService.getBuyingMultiplier(_currentUser!);
    final vehiclePrice = _vehicle.price * multiplier;
    
    final remainingBalance = currentBalance - vehiclePrice;
    final canAfford = remainingBalance >= 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              canAfford ? Icons.info_outline : Icons.warning_amber,
              color: canAfford ? Colors.deepPurple : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text('purchase.confirm'.tr()),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${'common.dear'.tr()} ${_currentUser!.username},',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('purchase.vehicle'.tr(), _vehicle.fullName),
              const Divider(),
              _buildInfoRow(
                'purchase.currentBalance'.tr(),
                '${_formatCurrency(currentBalance)} ${_currentUser!.currency}',
              ),
              _buildInfoRow(
                'purchase.vehiclePrice'.tr(),
                '${_formatCurrency(vehiclePrice)} TL',
                valueColor: Colors.red,
              ),
              const Divider(thickness: 2),
              _buildInfoRow(
                'purchase.remainingBalance'.tr(),
                '${_formatCurrency(remainingBalance)} ${_currentUser!.currency}',
                valueColor: canAfford ? Colors.green : Colors.red,
                isBold: true,
              ),
              if (!canAfford) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${'purchase.insufficientBalance'.tr()} ${_formatCurrency(vehiclePrice - currentBalance)} ${_currentUser!.currency} ${'purchase.missing'.tr()}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'purchase.confirmMessage'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: canAfford
                ? () {
                    Navigator.pop(context);
                    _processPurchase();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: Text('purchase.title'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _processPurchase() async {
    if (_currentUser == null) return;

    // Garaj limiti kontrolü
    final currentVehicleCount = await _db.getUserVehicleCount(_currentUser!.id);
    if (currentVehicleCount >= _currentUser!.garageLimit) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('myVehicles.garageFull'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.garage, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                '${'myVehicles.garageLimitReached'.tr()} (${_currentUser!.garageLimit})',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'myVehicles.expandGarageHint'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.ok'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Dialogu kapat
                Navigator.pop(context); // Detay sayfasını kapat
                // Mağaza sayfasına yönlendir (HomeScreen üzerinden veya direkt)
                // Şimdilik basitçe kullanıcıya mağazaya gitmesini söyleyelim
                // İleride direkt yönlendirme eklenebilir
              },
              child: Text('myVehicles.goToStore'.tr()),
            ),
          ],
        ),
      );
      return;
    }

    // 🎬 Tam ekran animasyon overlay'ini göster
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Geri tuşunu devre dışı bırak
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dönen çekiç/tokmak animasyonu
              Lottie.asset(
                'assets/animations/resolving_animation.json',
                width: 300,
                height: 300,
                repeat: false, // Sadece 1 kez oynat
              ),
              const SizedBox(height: 40),
              // Bilgi kutusu
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'purchase.purchasingVehicle'.tr(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_vehicle.brand} ${_vehicle.model}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'common.pleaseWait'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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

    // Animasyon süresi kadar bekle (~2 saniye)
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;
    Navigator.of(context).pop(); // Animasyon overlay'ini kapat

    try {
      // 1️⃣ Bakiyeyi düş (İndirimli fiyat)
      final multiplier = SkillService.getBuyingMultiplier(_currentUser!);
      final finalPrice = _vehicle.price * multiplier;
      
      final newBalance = _currentUser!.balance - finalPrice;
      final balanceUpdateSuccess = await _db.updateUser(
        _currentUser!.id,
        {'balance': newBalance},
      );

      if (!balanceUpdateSuccess) {
        throw Exception('errors.balanceUpdateFailed'.tr());
      }

      // 2️⃣ Aracı tüm kullanıcıların favorilerinden kaldır (ilan satıldı)
      await _favoriteService.removeVehicleFromAllFavorites(_vehicle.id);

      // 3️⃣ Aracı kullanıcıya ekle
      final userVehicle = UserVehicle.purchase(
        userId: _currentUser!.id,
        vehicleId: _vehicle.id,
        brand: _vehicle.brand,
        model: _vehicle.model,
        year: _vehicle.year,
        mileage: _vehicle.mileage,
        purchasePrice: finalPrice, // İndirimli fiyatı kaydet
        color: _vehicle.color,
        fuelType: _vehicle.fuelType,
        transmission: _vehicle.transmission,
        engineSize: _vehicle.engineSize,
        driveType: _vehicle.driveType,
        hasWarranty: _vehicle.hasWarranty,
        hasAccidentRecord: _vehicle.hasAccidentRecord,
        score: _vehicle.score, // İlan skoru (Vehicle'dan alınır)
        imageUrl: _vehicle.imageUrl,
      );

      final vehicleAddSuccess = await _db.addUserVehicle(userVehicle);

      if (!vehicleAddSuccess) {
        // Bakiyeyi geri yükle
        await _db.updateUser(
          _currentUser!.id,
          {'balance': _currentUser!.balance},
        );
        throw Exception('errors.vehicleAddFailed'.tr());
      }

      // 4️⃣ Kullanıcıyı güncelle
      await _loadCurrentUser();
      
      // 💎 XP Kazandır (Araç Satın Alma)
      final xpResult = await _xpService.onVehiclePurchase(_currentUser!.id);
      
      // 5️⃣ Başarılı! Kutlama göster
      HapticFeedback.heavyImpact(); // Güçlü titreşim - satın alma anı
      _confettiController.play();
      
      // XP Animasyonu göster (confetti ile birlikte)
      if (xpResult.hasGain && mounted) {
        _showXPGainAnimationOverlay(xpResult);
      }

      // 🎯 Günlük Görev Güncellemesi: Araç Satın Alma
      await _questService.updateProgress(_currentUser!.id, QuestType.buyVehicle, 1);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başarı ikonu
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'purchase.congratulations'.tr(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _vehicle.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'purchase.successfullyPurchased'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.celebration,
                        color: Colors.green,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'purchase.nowYours'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${'purchase.newBalance'.tr()}: ${_formatCurrency(newBalance)} TL',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Dialog'u kapat
                    Navigator.pop(context, true); // Detail sayfasından çık ve "satın alma başarılı" bilgisi gönder
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'purchase.great'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      // ❌ Hata durumu
      
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Text('purchase.purchaseError'.tr()),
            ],
          ),
          content: Text(
            '${'purchase.errorMessage'.tr()}\n\n$e\n\n${'purchase.tryAgain'.tr()}',
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

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpertiseCard() {
    final bool hasIssues = _vehicle.isExpertiseDone && 
        (_vehicle.declaredAccidentRecord != _vehicle.hasAccidentRecord || 
         _vehicle.declaredMileage != _vehicle.mileage ||
         _vehicle.declaredPartConditions.toString() != _vehicle.partConditions.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: _vehicle.isExpertiseDone 
            ? Border.all(color: hasIssues ? Colors.red : Colors.green, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fact_check, 
                    color: _vehicle.isExpertiseDone 
                        ? (hasIssues ? Colors.red : Colors.green)
                        : Colors.deepPurple, 
                    size: 24
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _vehicle.isExpertiseDone ? 'expertise.reportTitle'.tr() : 'expertise.statusTitle'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _vehicle.isExpertiseDone 
                          ? (hasIssues ? Colors.red : Colors.green)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_vehicle.isExpertiseDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasIssues ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hasIssues ? 'expertise.issueFound'.tr() : 'expertise.clean'.tr(),
                    style: TextStyle(
                      color: hasIssues ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_vehicle.isExpertiseDone) ...[
            Text(
              'expertise.disclaimer'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _currentUser != null ? _showExpertiseDialog : null,
                icon: const Icon(Icons.search),
                label: Text('expertise.performAction'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            // Rapor Detayları
            _buildExpertiseRow(
              'expertise.accidentRecord'.tr(), 
              _vehicle.declaredAccidentRecord ? 'expertise.exists'.tr() : 'expertise.none'.tr(),
              _vehicle.hasAccidentRecord ? 'expertise.exists'.tr() : 'expertise.none'.tr(),
              isIssue: _vehicle.declaredAccidentRecord != _vehicle.hasAccidentRecord
            ),
            const Divider(),
            _buildExpertiseRow(
              'expertise.mileage'.tr(), 
              '${_formatNumber(_vehicle.declaredMileage)} km',
              '${_formatNumber(_vehicle.mileage)} km',
              isIssue: _vehicle.declaredMileage != _vehicle.mileage
            ),
            const Divider(),
            _buildExpertiseRow(
              'expertise.partsCondition'.tr(), 
              _checkPartsStatus(_vehicle.declaredPartConditions),
              _checkPartsStatus(_vehicle.partConditions),
              isIssue: _vehicle.declaredPartConditions.toString() != _vehicle.partConditions.toString()
            ),
          ],
        ],
      ),
    );
  }

  String _checkPartsStatus(Map<String, String> parts) {
    final issueCount = parts.values.where((v) => v != 'orijinal').length;
    if (issueCount == 0) return 'expertise.partsClean'.tr();
    return '$issueCount ${'expertise.partsIssue'.tr()}';
  }

  Widget _buildExpertiseRow(String label, String declared, String real, {required bool isIssue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'expertise.declared'.tr()} $declared', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (isIssue)
                  Text('${'expertise.real'.tr()} $real', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                else
                  Text('expertise.verified'.tr(), style: const TextStyle(color: Colors.green, fontSize: 13)),
              ],
            ),
          ),
          if (isIssue)
            const Icon(Icons.warning, color: Colors.red, size: 20)
          else
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Future<void> _showExpertiseDialog() async {
    if (_currentUser == null) return;
    
    final cost = 3000.0;
    final canAfford = _currentUser!.balance >= cost;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('expertise.dialogTitle'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('expertise.dialogMessage'.tr()),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('expertise.fee'.tr()),
                Text(
                  '${_formatCurrency(cost)} TL',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            if (!canAfford)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'expertise.insufficientBalance'.tr(),
                  style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: canAfford 
                ? () {
                    Navigator.pop(context);
                    _performExpertise(cost);
                  }
                : null,
            child: Text('expertise.confirmAndPay'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _performExpertise(double cost) async {
    // 1. Ödemeyi al
    final newBalance = _currentUser!.balance - cost;
    await _db.updateUser(_currentUser!.id, {'balance': newBalance});
    await _loadCurrentUser(); // Bakiyeyi güncelle

    // 2. Animasyon göster (Opsiyonel, şimdilik loading)
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    await Future.delayed(const Duration(seconds: 2)); // Simüle et
    
    if (!mounted) return;
    Navigator.pop(context); // Loading kapat

    // 3. Gerçek değerleri hesapla ve güncelle
    // Eğer yalan varsa, fiyatı gerçek değerlere göre güncelle
    double newPrice = _vehicle.price;
    bool hasLies = _vehicle.declaredAccidentRecord != _vehicle.hasAccidentRecord || 
                   _vehicle.declaredMileage != _vehicle.mileage ||
                   _vehicle.declaredPartConditions.toString() != _vehicle.partConditions.toString();

    if (hasLies) {
      newPrice = _marketService.generateRealisticPrice(
        brand: _vehicle.brand,
        model: _vehicle.model,
        year: _vehicle.year,
        mileage: _vehicle.mileage, // Gerçek KM
        fuelType: _vehicle.fuelType,
        transmission: _vehicle.transmission,
        hasAccidentRecord: _vehicle.hasAccidentRecord, // Gerçek Hasar
        sellerType: _vehicle.sellerType,
        driveType: _vehicle.driveType,
        bodyType: _vehicle.bodyType,
        horsepower: _vehicle.horsepower,
      );
      
      // Fiyatı güncelle
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('expertise.issuesFoundMessage'.tr()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('expertise.cleanMessage'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    setState(() {
      _vehicle = _vehicle.copyWith(
        isExpertiseDone: true,
        price: newPrice,
        // declaredPrice değişmez, böylece referans olarak kalır
      );
    });
    
    // Market servisindeki ilanı güncelle (Kalıcılık için)
    _marketService.updateListing(_vehicle);
  }

  Widget _buildSpecificationsTab() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExpertiseCard(),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'vehicles.listingInfo'.tr(),
            icon: Icons.info_outline,
            children: [
              _buildInfoRow('vehicles.listingNo'.tr(), '#${_vehicle.id.substring(0, 8).toUpperCase()}'),
              _buildInfoRow('vehicles.listingDate'.tr(), _formatDate(_vehicle.listedAt)),
              _buildInfoRow('vehicles.sellerType'.tr(), _vehicle.sellerType),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'vehicles.vehicleInfo'.tr(),
            icon: Icons.directions_car,
            children: [
              _buildInfoRow('vehicles.brand'.tr(), _vehicle.brand),
              _buildInfoRow('vehicles.model'.tr(), _vehicle.model),
              _buildInfoRow('vehicles.year'.tr(), _vehicle.year.toString()),
              _buildInfoRow('vehicles.condition'.tr(), _vehicle.condition),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'vehicles.technicalSpecs'.tr(),
            icon: Icons.settings,
            children: [
              _buildInfoRow('vehicles.bodyType'.tr(), _vehicle.bodyType),
              _buildInfoRow('vehicles.engineSize'.tr(), '${_vehicle.engineSize} L'),
              _buildInfoRow('vehicles.horsepower'.tr(), '${_vehicle.horsepower} HP'),
              _buildInfoRow('vehicles.fuelType'.tr(), _vehicle.fuelType),
              _buildInfoRow('vehicles.transmission'.tr(), _vehicle.transmission),
              _buildInfoRow('vehicles.driveType'.tr(), _vehicle.driveType),
              _buildInfoRow('vehicles.mileage'.tr(), '${_formatNumber(_vehicle.mileage)} km'),
              _buildInfoRow('vehicles.color'.tr(), _vehicle.color),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'vehicles.statusWarranty'.tr(),
            icon: Icons.verified_user,
            children: [
              _buildInfoRow(
                'vehicles.warrantyStatus'.tr(),
                _vehicle.hasWarranty ? '✅ ${'vehicles.available'.tr()}' : '❌ ${'vehicles.notAvailable'.tr()}',
                valueColor: _vehicle.hasWarranty ? Colors.green : Colors.red,
              ),
              _buildInfoRow(
                'vehicles.accidentRecord'.tr(),
                _vehicle.hasAccidentRecord ? '⚠️ ${'vehicles.yes'.tr()}' : '✅ ${'vehicles.no'.tr()}',
                valueColor: _vehicle.hasAccidentRecord ? Colors.red : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Araç Görseli (Üstten Bakış)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.build_circle, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'vehicles.paintedOrReplacedParts'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: VehicleTopView(
                    partConditions: _vehicle.partConditions,
                    width: 250,
                    height: 400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionTab() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.deepPurple, size: 24),
                const SizedBox(width: 12),
                Text(
                  'vehicles.sellerNote'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _vehicle.description,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'vehicles.funDisclaimer'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
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

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy', LocalizationService().currentLanguage == 'tr' ? 'tr_TR' : 'en_US').format(date);
  }

  /// Teklif verme dialogunu göster
  Future<void> _showMakeOfferDialog() async {
    final TextEditingController offerController = TextEditingController();

    // Önceden reddedilmiş teklif var mı kontrol et
    if (_currentUser != null) {
      final previousOffers = await _db.getOffersByBuyerId(_currentUser!.id);
      final rejectedOffer = previousOffers.where((o) => 
        o.vehicleId == _vehicle.id && 
        o.status == OfferStatus.rejected
      ).firstOrNull;

      if (rejectedOffer != null) {
        // Reddedilmiş teklif varsa kullanıcıyı bilgilendir
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text('offer.cannotSendOffer'.tr()),
              ],
            ),
            content: Text('offer.previousOfferRejected'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.ok'.tr()),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('offer.makeOffer'.tr()),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_vehicle.brand} ${_vehicle.model}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${'offer.listingPrice'.tr()}: ${_formatCurrency(_vehicle.price)} TL',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: offerController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ThousandsSeparatorInputFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'offer.yourOffer'.tr(),
                  hintText: 'offer.enterAmount'.tr(),
                  suffixText: 'TL',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.money),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final offerText = offerController.text.trim();
              if (offerText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('offer.enterAmountError'.tr())),
                );
                return;
              }

              // Noktaları kaldır (1.000.000 -> 1000000)
              final cleanedText = offerText.replaceAll('.', '');
              final offerAmount = double.tryParse(cleanedText);
              if (offerAmount == null || offerAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('offer.invalidAmountError'.tr())),
                );
                return;
              }

              if (offerAmount >= _vehicle.price) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('offer.offerTooHighError'.tr())),
                );
                return;
              }

              Navigator.pop(context);
              _showConfirmOfferDialog(offerAmount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: Text('common.continue'.tr()),
          ),
        ],
      ),
    );
  }

  /// Teklif onay dialogunu göster
  void _showConfirmOfferDialog(double offerAmount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('offer.confirmOffer'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'offer.confirmOfferMessage'.tr(),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_vehicle.brand} ${_vehicle.model}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'offer.listingPrice'.tr(),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        '${_formatCurrency(_vehicle.price)} TL',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'offer.yourOffer'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_formatCurrency(offerAmount)} TL',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'offer.checkResultsInMyOffers'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitOffer(offerAmount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: Text('offer.sendOffer'.tr()),
          ),
        ],
      ),
    );
  }

  /// Teklifi gönder
  Future<void> _submitOffer(double offerAmount) async {
    if (_currentUser == null) return;

    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await _offerService.submitUserOffer(
        userId: _currentUser!.id,
        userName: _currentUser!.username,
        vehicle: _vehicle,
        offerPrice: offerAmount,
        message: null,
      );

      // Loading kapat
      if (mounted) Navigator.pop(context);

      if (!result['success']) {
        throw Exception(result['error'] ?? 'Unknown error');
      }
      
      // 💎 XP Kazandır (Teklif Gönderme)
      final xpResult = await _xpService.onOfferMade(_currentUser!.id);
      if (xpResult.hasGain && mounted) {
        // Sessiz XP (küçük miktar, animasyon gösterme)
        // _showXPGainAnimationOverlay(xpResult); // İsteğe bağlı
      }
      
      // 🎯 Günlük Görev Güncellemesi: Teklif Gönderme
      await _questService.updateProgress(_currentUser!.id, QuestType.makeOffer, 1);
      
      // Eğer teklif kabul edildiyse ekstra XP
      if (result['decision'] == 'accept') {
        final acceptXP = await _xpService.onOfferAccepted(_currentUser!.id);
        if (acceptXP.hasGain && mounted) {
          _showXPGainAnimationOverlay(acceptXP);
        }
      }

      // Sonuç dialogunu göster ve yönlendir
      _showOfferResultDialog(result);
    } catch (e) {
      // Loading kapat
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'offer.sendError'.tr()}\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Teklif sonuç dialogunu göster
  void _showOfferResultDialog(Map<String, dynamic> result) {
    final decision = result['decision'] as String;
    final response = result['response'] as String;
    final counterOffer = result['counterOffer'] as double?;
    final offer = result['offer'] as Offer?;

    IconData icon;
    Color iconColor;
    String title;

    if (decision == 'accept') {
      icon = Icons.check_circle;
      iconColor = Colors.green;
      title = 'offer.accepted'.tr();
    } else if (decision == 'reject') {
      icon = Icons.cancel;
      iconColor = Colors.red;
      title = 'offer.rejected'.tr();
    } else {
      icon = Icons.swap_horiz;
      iconColor = Colors.orange;
      title = 'offer.counterOffer'.tr();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              response,
              style: const TextStyle(fontSize: 16),
            ),
            if (counterOffer != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer, color: Colors.orange),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'offer.counterOfferAmount'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${_formatCurrency(counterOffer)} TL',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'offer.viewInMyOffers'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('common.ok'.tr()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Dialog'u kapat
                        // MyOffers sayfasına yönlendir (Gönderdiğim Teklifler sekmesi)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyOffersScreen(initialTab: 1),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'offer.viewOffers'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (decision == 'counter' && counterOffer != null && offer != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Dialog'u kapat
                      _handleAcceptCounterOffer(offer);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('common.accept'.tr()),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Karşı teklifi kabul et
  Future<void> _handleAcceptCounterOffer(Offer offer) async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _offerService.acceptCounterOffer(offer);
      
      // Loading kapat
      if (mounted) Navigator.pop(context);

      if (result['success']) {
        if (mounted) {
          // Başarılı mesajı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('offer.offerAcceptedAndPurchased'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          
          // Konfetiyi patlat (opsiyonel ama hoş olur)
          // Konfetiyi patlat (opsiyonel ama hoş olur)
          _confettiController.play();
          
          // Biraz bekle ve araçlarım sayfasına git
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MyVehiclesScreen(),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'common.error'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Loading kapat
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('errors.errorWithDetail'.trParams({'detail': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // ========== XP SİSTEMİ METODLARI ==========
  
  /// XP kazanım animasyonu göster (overlay)
  void _showXPGainAnimationOverlay(XPGainResult result) {
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
              // Level up varsa dialog göster
              if (result.leveledUp && mounted) {
                _showLevelUpDialog(result);
              }
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
              'xp.level'.trParams({'level': result.newLevel.toString()}),
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
}

/// Binlik ayracı ekleyen TextInputFormatter
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###', 'tr_TR');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Sadece sayıları al
    final numericValue = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (numericValue.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Sayıyı formatla
    final number = int.parse(numericValue);
    final formattedText = _formatter.format(number);

    // Cursor pozisyonunu ayarla
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

