import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../models/vehicle_model.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import '../models/offer_model.dart';
import '../services/auth_service.dart';
import '../services/ad_service.dart';
import '../services/database_helper.dart';
import '../services/offer_service.dart';
import '../services/favorite_service.dart';
import '../services/localization_service.dart';
import '../services/xp_service.dart';
import '../services/activity_service.dart';
import '../services/daily_quest_service.dart';
import '../models/daily_quest_model.dart';
import '../services/market_refresh_service.dart'; // Market Servisi (Fiyat hesaplama için)
import '../services/screen_refresh_service.dart';
import '../widgets/vehicle_top_view.dart';
import '../widgets/level_up_dialog.dart';
import '../services/skill_service.dart';
import '../models/seller_profile_model.dart';
import '../widgets/modern_alert_dialog.dart';

import '../widgets/vehicle_image.dart';
import '../widgets/game_image.dart';
import 'package:intl/intl.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  final OfferService _offerService = OfferService();
  final FavoriteService _favoriteService = FavoriteService();
  final XPService _xpService = XPService();
  final DailyQuestService _questService = DailyQuestService();
  final MarketRefreshService _marketService = MarketRefreshService();
  final SkillService _skillService = SkillService();
  User? _currentUser;
  bool _isFavorite = false;
  bool _isLoading = false;
  late Vehicle _vehicle;
  late SellerProfile _sellerProfile;

  StreamSubscription? _userUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
    _sellerProfile = SellerProfile.generateRandom(
      seed: widget.vehicle.id.hashCode,
    );
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();

    // Kullanıcı güncellemelerini dinle
    _userUpdateSubscription = _db.onUserUpdate.listen((_) {
      _loadCurrentUser();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userUpdateSubscription?.cancel();
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
      final success = await _favoriteService.removeFavorite(
        _currentUser!.id,
        _vehicle.id,
      );
      if (success) {
        setState(() {
          _isFavorite = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text('favorites.removedFromFavorites'.tr()),
              backgroundColor: Colors.orange.withValues(alpha: 0.8),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      }
    } else {
      // Favorilere ekle
      final success = await _favoriteService.addFavorite(
        _currentUser!.id,
        _vehicle,
      );
      if (success) {
        setState(() {
          _isFavorite = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text('favorites.addedToFavorites'.tr()),
              backgroundColor: Colors.green.withValues(alpha: 0.8),
              duration: const Duration(milliseconds: 1500),
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
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
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
                            // Araç Resmi veya Placeholder
                            if (_vehicle.imageUrl != null &&
                                _vehicle.imageUrl!.isNotEmpty)
                              Center(
                                child: AspectRatio(
                                  aspectRatio:
                                      120 /
                                      140, // Liste ekranındaki gerçek oran (Container width: 120)
                                  child: VehicleImage(
                                    vehicle: _vehicle,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              )
                            else
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
                                      Colors.black.withValues(alpha: 0.7),
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
                                _vehicle.fullName.replaceAll(
                                  'Serisi',
                                  'vehicles.series'.tr(),
                                ),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'vehicles.price'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Flexible(child: _buildPriceDisplay()),
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
                      color: Colors.black.withValues(alpha: 0.1),
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
                          onPressed: _currentUser != null
                              ? () => _showMakeOfferDialog()
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: Colors.deepPurple,
                              width: 2,
                            ),
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
                          onPressed: _currentUser != null
                              ? () => _showPurchaseDialog()
                              : null,
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
            // Loading Indicator
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.deepOrange),
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
    final bool priceDropped =
        _vehicle.isExpertiseDone && _vehicle.price < _vehicle.declaredPrice;

    if (!priceDropped) {
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
        // 1. İlan Fiyatı (Ekspertiz düşüşü varsa)
        if (priceDropped) ...[
          Text(
            'offer.listingPrice'.tr(),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            '${_formatCurrency(_vehicle.declaredPrice)} TL',
            style: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.red,
              decorationThickness: 2,
              color: Colors.grey[500],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
        ],

        // 2. Ara Fiyat (Ekspertiz sonrası, yetenek indirimi öncesi)

        // Sadece ekspertiz indirimi var
        if (priceDropped)
          Text(
            'expertise.value'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        Text(
          '${_formatCurrency(_vehicle.price)} TL',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: priceDropped ? Colors.green : Colors.deepPurple,
          ),
        ),
      ],
    );
  }

  Future<void> _showPurchaseDialog() async {
    if (_currentUser == null) return;

    final currentBalance = _currentUser!.balance;
    // Yetenek indirimi uygula
    final vehiclePrice = _vehicle.price;

    final remainingBalance = currentBalance - vehiclePrice;
    final canAfford = remainingBalance >= 0;

    showDialog(
      context: context,
      builder: (dialogContext) => ModernAlertDialog(
        title: 'purchase.confirm'.tr(),
        icon: canAfford ? Icons.info_outline : Icons.warning_amber,
        iconColor: canAfford ? Colors.deepPurple : Colors.orange,
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
              _buildInfoRow(
                'purchase.vehicle'.tr(),
                _vehicle.fullName.replaceAll('Serisi', 'vehicles.series'.tr()),
              ),
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
                    color: Colors.orange.withValues(alpha: 0.1),
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext); // Dialogu kapat
                      Navigator.pop(
                        context,
                      ); // Detay sayfasını kapat (Outer context)
                      ScreenRefreshService().requestTabChange(
                        6,
                      ); // Mağaza sayfasına git
                    },
                    icon: const Icon(Icons.store, size: 18),
                    label: Text('myVehicles.goToStore'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
        buttonText: 'purchase.title'.tr(),
        onPressed: canAfford
            ? () {
                Navigator.pop(dialogContext);
                _processPurchase();
              }
            : () {}, // Disabled handled by logic inside content or logic here? ModernAlertDialog doesn't support disabled button yet.
        // Wait, ModernAlertDialog button is always enabled. I should probably add logic to ModernAlertDialog to support disabled state or just handle it here.
        // Since I can't easily change ModernAlertDialog signature again without updating all usages, I'll just keep it enabled but maybe show a snackbar or just do nothing if clicked when not affordable?
        // Actually, the original code had `onPressed: canAfford ? ... : null`.
        // I will modify ModernAlertDialog to accept `onPressed: null` to disable button? No, `VoidCallback` is required.
        // I'll just pass a no-op function if not affordable, but the button will look enabled.
        // Better: I'll add a check inside the onPressed.
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(dialogContext),
      ),
    );
  }

  Future<void> _processPurchase() async {
    if (_currentUser == null) return;

    // Garaj limiti kontrolü
    final currentVehicleCount = await _db.getUserPersonalVehicleCount(
      _currentUser!.id,
    );
    if (currentVehicleCount >= _currentUser!.garageLimit) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => ModernAlertDialog(
          title: 'myVehicles.garageFull'.tr(),
          icon: Icons.garage,
          iconColor: Colors.orange,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
          buttonText: 'myVehicles.goToStore'.tr(),
          onPressed: () {
            Navigator.pop(dialogContext); // Dialogu kapat
            Navigator.pop(
              context,
            ); // Detay sayfasını kapat (Outer context kullan)
            // Mağaza sayfasına yönlendir (HomeScreen üzerinden)
            ScreenRefreshService().requestTabChange(6); // 6: Store Tab
          },
          secondaryButtonText: 'common.ok'.tr(),
          onSecondaryPressed: () => Navigator.pop(dialogContext),
        ),
      );
      return;
    }

    // 🎬 Animasyon göster
    await _playPurchaseAnimation();

    try {
      // 1️⃣ Bakiyeyi düş (İndirimli fiyat)
      final finalPrice = _vehicle.price;

      final newBalance = _currentUser!.balance - finalPrice;
      final balanceUpdateSuccess = await _db.updateUser(_currentUser!.id, {
        'balance': newBalance,
      });

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
        bodyType: _vehicle.bodyType,
        horsepower: _vehicle.horsepower,
        imageUrl: _vehicle.imageUrl,
        originalListingPrice:
            _vehicle.price, // 🆕 Orijinal ilan fiyatını kaydet
      );

      final vehicleAddSuccess = await _db.addUserVehicle(userVehicle);

      // 4️⃣ İlanı kaldır (Marketten sil)
      _marketService.removeListing(_vehicle.id);

      if (!vehicleAddSuccess) {
        // Bakiyeyi geri yükle
        await _db.updateUser(_currentUser!.id, {
          'balance': _currentUser!.balance,
        });
        throw Exception('errors.vehicleAddFailed'.tr());
      }

      // 4️⃣ Kullanıcıyı güncelle
      await _loadCurrentUser();

      // 💎 XP Kazandır (Araç Satın Alma)
      final xpResult = await _xpService.onVehiclePurchase(_currentUser!.id);

      // 5️⃣ Başarılı! Kutlama göster
      HapticFeedback.heavyImpact(); // Güçlü titreşim - satın alma anı
      // XP Animasyonu göster (confetti ile birlikte)
      if (xpResult.hasGain && mounted) {
        _showXPGainAnimationOverlay(xpResult);
      }

      // 🎯 Günlük Görev Güncellemesi: Araç Satın Alma
      await _questService.updateProgress(
        _currentUser!.id,
        QuestType.buyVehicle,
        1,
        brand: _vehicle.brand,
      );

      // Aktivite kaydı
      await ActivityService().logVehiclePurchase(_currentUser!.id, userVehicle);

      if (!mounted) return;

      // Başarılı dialogu göster
      _showPurchaseSuccessDialog(_currentUser!.balance);
    } catch (e) {
      // ❌ Hata durumu

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => ModernAlertDialog(
          title: 'purchase.purchaseError'.tr(),
          icon: Icons.error_outline,
          iconColor: Colors.red,
          content: Text(
            '${'purchase.errorMessage'.tr()}\n\n$e\n\n${'purchase.tryAgain'.tr()}',
            textAlign: TextAlign.center,
          ),
          buttonText: 'common.ok'.tr(),
          onPressed: () => Navigator.pop(context),
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
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
    final bool hasIssues =
        _vehicle.isExpertiseDone &&
        (_vehicle.declaredAccidentRecord != _vehicle.hasAccidentRecord ||
            _vehicle.declaredMileage != _vehicle.mileage ||
            _vehicle.declaredPartConditions.toString() !=
                _vehicle.partConditions.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _vehicle.isExpertiseDone
                        ? 'expertise.reportTitle'.tr()
                        : 'expertise.statusTitle'.tr(),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasIssues
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hasIssues
                        ? 'expertise.issueFound'.tr()
                        : 'expertise.clean'.tr(),
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
              child: Builder(
                builder: (context) {
                  final hasSkill =
                      _currentUser != null &&
                      _skillService.getSkillLevel(
                            _currentUser!,
                            SkillService.skillExpertiseExpert,
                          ) >
                          0;
                  final remainingUses = _currentUser != null
                      ? _skillService.getRemainingDailyUses(
                          _currentUser!,
                          SkillService.skillExpertiseExpert,
                        )
                      : 0;
                  final hasUnlimitedExpertise =
                      _currentUser?.hasUnlimitedExpertise ?? false;
                  final isFree =
                      hasUnlimitedExpertise || (hasSkill && remainingUses > 0);

                  // Calculate dynamic cost for display
                  double cost = 0.0;
                  if (!isFree) {
                    double calculatedFee = _vehicle.price * 0.005;
                    if (calculatedFee < 5000.0) calculatedFee = 5000.0;
                    if (calculatedFee > 50000.0) calculatedFee = 50000.0;
                    cost = (calculatedFee / 50).ceil() * 50.0;
                  }

                  String buttonText;
                  if (hasUnlimitedExpertise) {
                    buttonText = '${'skills.freeExpertise'.tr()} (VIP)';
                  } else if (isFree) {
                    buttonText =
                        '${'skills.freeExpertise'.tr()} ($remainingUses/${SkillService.skillDefinitions[SkillService.skillExpertiseExpert]!['dailyLimit']})';
                  } else {
                    buttonText =
                        '${'expertise.performActionNoPrice'.tr()} (${_formatCurrency(cost)} TL)';
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _currentUser != null
                            ? () => _showExpertiseDialog(isFree: isFree)
                            : null,
                        icon: Icon(isFree ? Icons.auto_awesome : Icons.search),
                        label: Text(buttonText),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFree
                              ? Colors.indigo
                              : Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      if (!isFree) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            // Reklam yükleniyor mu kontrol et
                            if (!AdService().isAdReady) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('common.adNotReady'.tr()),
                                ),
                              );
                              // Reklam yüklemeyi dene
                              AdService().loadRewardedAd();
                              return;
                            }

                            // Reklamı göster
                            final rewardEarned = await AdService()
                                .showRewardedAd(
                                  onRewarded: (reward) {
                                    // Ödül kazanıldı, ücretsiz ekspertiz yap
                                    _performExpertise(0, isFree: true);
                                  },
                                );

                            if (!rewardEarned) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('common.adFailed'.tr())),
                              );
                            }
                          },
                          icon: const Icon(Icons.ondemand_video),
                          label: Text('skills.watchAd'.tr()),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.purple,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ] else ...[
            // Rapor Detayları
            _buildExpertiseRow(
              'expertise.accidentRecord'.tr(),
              _vehicle.declaredAccidentRecord
                  ? 'expertise.exists'.tr()
                  : 'expertise.none'.tr(),
              _vehicle.hasAccidentRecord
                  ? 'expertise.exists'.tr()
                  : 'expertise.none'.tr(),
              isIssue:
                  _vehicle.declaredAccidentRecord != _vehicle.hasAccidentRecord,
            ),
            const Divider(),
            _buildExpertiseRow(
              'expertise.mileage'.tr(),
              '${_formatNumber(_vehicle.declaredMileage)} km',
              '${_formatNumber(_vehicle.mileage)} km',
              isIssue: _vehicle.declaredMileage != _vehicle.mileage,
            ),
            const Divider(),
            _buildExpertiseRow(
              'expertise.partsCondition'.tr(),
              _checkPartsStatus(_vehicle.declaredPartConditions),
              _checkPartsStatus(_vehicle.partConditions),
              isIssue:
                  _vehicle.declaredPartConditions.toString() !=
                  _vehicle.partConditions.toString(),
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

  Widget _buildExpertiseRow(
    String label,
    String declared,
    String real, {
    required bool isIssue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'expertise.declared'.tr()} $declared',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (isIssue)
                  Text(
                    '${'expertise.real'.tr()} $real',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Text(
                    'expertise.verified'.tr(),
                    style: const TextStyle(color: Colors.green, fontSize: 13),
                  ),
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

  Future<void> _showExpertiseDialog({bool isFree = false}) async {
    if (_currentUser == null) return;

    if (_currentUser!.hasUnlimitedExpertise) {
      isFree = true;
    }

    double cost = 0.0;
    if (!isFree) {
      // Dinamik ekspertiz ücreti: Araç fiyatının %0.5'i
      // Min: 5.000 TL, Max: 50.000 TL
      double calculatedFee = _vehicle.price * 0.005;

      if (calculatedFee < 5000.0) calculatedFee = 5000.0;
      if (calculatedFee > 50000.0) calculatedFee = 50000.0;

      // 50 TL'nin katlarına yuvarla
      cost = (calculatedFee / 50).ceil() * 50.0;
    }

    final canAfford = _currentUser!.balance >= cost;

    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: isFree
            ? 'skills.freeExpertise'.tr()
            : 'expertise.dialogTitle'.tr(),
        icon: isFree ? Icons.auto_awesome : Icons.fact_check,
        iconColor: isFree ? Colors.indigo : Colors.deepPurple,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFree
                  ? (_currentUser!.hasUnlimitedExpertise
                        ? 'skills.unlimitedExpertiseDesc'.tr()
                        : 'skills.expertiseExpertDesc'.tr())
                  : 'expertise.dialogMessage'.tr(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('expertise.fee'.tr()),
                Text(
                  isFree ? 'common.free'.tr() : '${_formatCurrency(cost)} TL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFree ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (!canAfford && !isFree)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'expertise.insufficientBalance'.tr(),
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        buttonText: isFree
            ? 'common.continue'.tr()
            : 'expertise.confirmAndPay'.tr(),
        onPressed: (canAfford || isFree)
            ? () {
                Navigator.pop(context);
                _performExpertise(cost, isFree: isFree);
              }
            : () {}, // ModernAlertDialog doesn't support disabled button, handle logic inside or show message
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _performExpertise(double cost, {bool isFree = false}) async {
    // 1. Ödemeyi al veya kullanım kaydet
    if (isFree) {
      await _skillService.recordSkillUsage(
        _currentUser!.id,
        SkillService.skillExpertiseExpert,
      );
    } else {
      final newBalance = _currentUser!.balance - cost;
      await _db.updateUser(_currentUser!.id, {'balance': newBalance});
    }
    await _loadCurrentUser(); // Bakiyeyi veya yetenek kullanımını güncelle

    // 2. Animasyon göster
    if (!mounted) return;

    bool isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Lottie.asset(
            'assets/animations/satinal.json',
            width: 300,
            height: 300,
            repeat: false,
          ),
        ),
      ),
    ).then((_) => isDialogShowing = false);

    await Future.delayed(const Duration(seconds: 3)); // Animasyon süresi

    if (!mounted) return;

    // Sadece dialog hala açıksa kapat
    if (isDialogShowing) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // 3. Gerçek değerleri hesapla ve güncelle
    // Eğer yalan varsa, fiyatı gerçek değerlere göre güncelle
    double newPrice = _vehicle.price;
    bool hasLies =
        _vehicle.declaredAccidentRecord != _vehicle.hasAccidentRecord ||
        _vehicle.declaredMileage != _vehicle.mileage ||
        _vehicle.declaredPartConditions.toString() !=
            _vehicle.partConditions.toString();

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

      // Eğer hesaplanan gerçek fiyat, beyan edilen fiyattan düşük değilse
      // (Piyasa dalgalanmaları veya rastgele faktörler nedeniyle olabilir)
      // Kullanıcıya "sorun bulundu" dediğimiz için mutlaka fiyatı düşürmeliyiz.
      if (newPrice >= _vehicle.declaredPrice) {
        // En az %5 indirim uygula
        newPrice = _vehicle.declaredPrice * 0.95;
      }

      // Fiyatı güncelle
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            content: Text('expertise.issuesFoundMessage'.tr()),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            content: Text('expertise.cleanMessage'.tr()),
            backgroundColor: Colors.green.withValues(alpha: 0.8),
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
              _buildInfoRow(
                'vehicles.listingNo'.tr(),
                '#${_vehicle.id.substring(0, 8).toUpperCase()}',
              ),
              _buildInfoRow(
                'vehicles.listingDate'.tr(),
                _formatDate(_vehicle.listedAt),
              ),
              _buildInfoRow(
                'vehicles.sellerType'.tr(),
                'vehicles.${_vehicle.sellerType}'.tr(),
              ),
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
              _buildInfoRow(
                'vehicles.condition'.tr(),
                'vehicles.${_vehicle.condition}'.tr(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'vehicles.technicalSpecs'.tr(),
            icon: Icons.settings,
            children: [
              _buildInfoRow(
                'vehicles.bodyType'.tr(),
                'vehicles.${_vehicle.bodyType.toLowerCase()}'.tr(),
              ),
              _buildInfoRow(
                'vehicles.engineSize'.tr(),
                '${_vehicle.engineSize} L',
              ),
              _buildInfoRow(
                'vehicles.horsepower'.tr(),
                '${_vehicle.horsepower} HP',
              ),
              _buildInfoRow(
                'vehicles.fuelType'.tr(),
                'vehicles.${_vehicle.fuelType}'.tr(),
              ),
              _buildInfoRow(
                'vehicles.transmission'.tr(),
                'vehicles.${_vehicle.transmission}'.tr(),
              ),
              _buildInfoRow(
                'vehicles.driveType'.tr(),
                'vehicles.${_vehicle.driveType}'.tr(),
              ),
              _buildInfoRow(
                'vehicles.mileage'.tr(),
                '${_formatNumber(_vehicle.mileage)} km',
              ),
              if (_vehicle.color != 'Standart')
                _buildInfoRow(
                  'vehicles.color'.tr(),
                  'vehicles.${_vehicle.color}'.tr(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'vehicles.statusWarranty'.tr(),
            icon: Icons.verified_user,
            children: [
              _buildInfoRow(
                'vehicles.warrantyStatus'.tr(),
                _vehicle.hasWarranty
                    ? '✅ ${'vehicles.available'.tr()}'
                    : '❌ ${'vehicles.notAvailable'.tr()}',
                valueColor: _vehicle.hasWarranty ? Colors.green : Colors.red,
              ),
              _buildInfoRow(
                'vehicles.accidentRecord'.tr(),
                _vehicle.hasAccidentRecord
                    ? '⚠️ ${'vehicles.yes'.tr()}'
                    : '✅ ${'vehicles.no'.tr()}',
                valueColor: _vehicle.hasAccidentRecord
                    ? Colors.red
                    : Colors.green,
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
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.build_circle,
                      color: Colors.deepPurple,
                      size: 20,
                    ),
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
              color: Colors.black.withValues(alpha: 0.05),
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
            color: Colors.black.withValues(alpha: 0.05),
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
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
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
    return DateFormat(
      'dd MMMM yyyy',
      LocalizationService().currentLanguage == 'tr' ? 'tr_TR' : 'en_US',
    ).format(date);
  }

  /// Teklif verme dialogunu göster
  Future<void> _showMakeOfferDialog() async {
    final TextEditingController offerController = TextEditingController();

    // 🆕 Initialize SellerProfile with deterministic seed
    double acceptanceChance = 0.0;

    // Önceden reddedilmiş teklif var mı kontrol et
    if (_currentUser != null) {
      final previousOffers = await _db.getOffersByBuyerId(_currentUser!.id);
      final rejectedOffer = previousOffers
          .where(
            (o) =>
                o.vehicleId == _vehicle.id && o.status == OfferStatus.rejected,
          )
          .firstOrNull;

      if (rejectedOffer != null) {
        // Reddedilmiş teklif varsa kullanıcıyı bilgilendir
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => ModernAlertDialog(
            title: 'offer.cannotSendOffer'.tr(),
            content: Text('offer.previousOfferRejected'.tr()),
            buttonText: 'common.ok'.tr(),
            onPressed: () => Navigator.pop(context),
            icon: Icons.warning,
            iconColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return ModernAlertDialog(
            title: 'offer.makeOffer'.tr(),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text(
                  //   '${_vehicle.brand} ${_vehicle.model}',
                  //   style: const TextStyle(
                  //     fontSize: 16,
                  //     fontWeight: FontWeight.bold,
                  //     color: Colors.white,
                  //   ),
                  // ),
                  const SizedBox(height: 8),
                  Text(
                    '${'offer.listingPrice'.tr()}: ${_formatCurrency(_vehicle.price)} TL',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: offerController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'offer.yourOffer'.tr(),
                      labelStyle: const TextStyle(color: Colors.white70),
                      suffixText: 'TL',
                      suffixStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      prefixIcon: const Icon(
                        Icons.attach_money,
                        color: Colors.white70,
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setState(() {
                          acceptanceChance = 0.0;
                        });
                        return;
                      }

                      final offerAmount =
                          double.tryParse(value.replaceAll('.', '')) ?? 0;

                      // Calculate acceptance chance using SellerProfile
                      double chance = _sellerProfile.calculateAcceptanceChance(
                        offerPrice: offerAmount,
                        listingPrice: _vehicle.price,
                        buyerUser: _currentUser,
                      );

                      setState(() {
                        acceptanceChance = chance.clamp(0.0, 1.0);
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Kabul Edilme İhtimali Barı
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'offer.acceptanceChance'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '%${(acceptanceChance * 100).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: acceptanceChance > 0.7
                                  ? Colors.greenAccent
                                  : (acceptanceChance > 0.3
                                        ? Colors.orangeAccent
                                        : Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Colors.red, Colors.orange, Colors.green],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.centerLeft,
                          children: [
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              alignment: Alignment(
                                (acceptanceChance * 2) -
                                    1, // Map 0.0..1.0 to -1.0..1.0
                                0.0,
                              ),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: acceptanceChance > 0.7
                                        ? Colors.green
                                        : (acceptanceChance > 0.3
                                              ? Colors.orange
                                              : Colors.red),
                                    width: 2,
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
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            buttonText: 'offer.sendOffer'.tr(),
            onPressed: () {
              final offerText = offerController.text.trim();
              if (offerText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    behavior: SnackBarBehavior.floating,
                    content: Text('offer.enterAmountError'.tr()),
                    backgroundColor: Colors.red.withValues(alpha: 0.8),
                  ),
                );
                return;
              }

              // Noktaları kaldır (1.000.000 -> 1000000)
              final cleanedText = offerText.replaceAll('.', '');
              final offerAmount = double.tryParse(cleanedText);
              if (offerAmount == null || offerAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    behavior: SnackBarBehavior.floating,
                    content: Text('offer.invalidAmountError'.tr()),
                    backgroundColor: Colors.red.withValues(alpha: 0.8),
                  ),
                );
                return;
              }

              if (offerAmount >= _vehicle.price) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    behavior: SnackBarBehavior.floating,
                    content: Text('offer.offerTooHighError'.tr()),
                    backgroundColor: Colors.red.withValues(alpha: 0.8),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _showConfirmOfferDialog(offerAmount);
            },
            secondaryButtonText: 'common.cancel'.tr(),
            onSecondaryPressed: () => Navigator.pop(context),
          );
        },
      ),
    );
  }

  void _showConfirmOfferDialog(double offerAmount) {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'offer.confirmOffer'.tr(),
        // icon: Icons.help_outline, // Removed
        // iconColor: Colors.deepPurple, // Removed
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'offer.confirmOfferMessage'.tr(),
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_vehicle.brand} ${_vehicle.model}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'offer.listingPrice'.tr(),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '${_formatCurrency(_vehicle.price)} TL',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'offer.yourOffer'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_formatCurrency(offerAmount)} TL',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // const SizedBox(height: 16), // Removed info container
            // Info container removed
          ],
        ),
        buttonText: 'offer.sendOffer'.tr(),
        onPressed: () {
          Navigator.pop(context);
          _submitOffer(offerAmount);
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// Teklifi gönder
  /// Teklifi gönder
  Future<void> _submitOffer(double offerAmount) async {
    if (_currentUser == null) return;

    // Loading göster
    setState(() {
      _isLoading = true;
    });

    try {
      // 10 saniye timeout ekle
      final result = await _offerService
          .submitUserOffer(
            userId: _currentUser!.id,
            userName: _currentUser!.username,
            vehicle: _vehicle,
            offerPrice: offerAmount,
            message: null,
          )
          .timeout(const Duration(seconds: 10));

      // Loading kapat
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (!result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 6,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.red.shade600,
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result['error'] ?? 'Unknown error',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return;
      }

      // 💎 XP Kazandır (Teklif Gönderme)
      final xpResult = await _xpService.onOfferMade(_currentUser!.id);
      if (xpResult.hasGain && mounted) {
        // Sessiz XP (küçük miktar, animasyon gösterme)
        // _showXPGainAnimationOverlay(xpResult); // İsteğe bağlı
      }

      // 🎯 Günlük Görev Güncellemesi: Teklif Gönderme
      await _questService.updateProgress(
        _currentUser!.id,
        QuestType.makeOffer,
        1,
      );

      // Eğer teklif kabul edildiyse ekstra XP ve Satın Alma İşlemleri
      if (result['decision'] == 'accept') {
        final acceptXP = await _xpService.onOfferAccepted(_currentUser!.id);
        if (acceptXP.hasGain && mounted) {
          _showXPGainAnimationOverlay(acceptXP);
        }

        // 🎬 Animasyon göster
        await _playPurchaseAnimation();

        // İlanı kaldır (Marketten sil)
        _marketService.removeListing(_vehicle.id);

        // Kullanıcıyı güncelle (bakiye değişti)
        await _loadCurrentUser();

        // Başarı dialogunu göster
        if (mounted && _currentUser != null) {
          _showPurchaseSuccessDialog(_currentUser!.balance);
        }
      } else {
        // Sonuç dialogunu göster (Red veya Karşı Teklif)
        _showOfferResultDialog(result);
      }
    } catch (e) {
      // Loading kapat
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 6,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red.shade600,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
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
      builder: (context) => PopScope(
        canPop: false, // Geri tuşu ile kapatmayı engelle
        child: AlertDialog(
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
              Text(response, style: const TextStyle(fontSize: 16)),
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
                        style: TextStyle(fontSize: 13, color: Colors.blue[900]),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (decision == 'counter' &&
                    counterOffer != null &&
                    offer != null) ...[
                  // Accept Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAcceptCounterOffer(offer);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('offers.accept'.tr()),
                  ),
                  const SizedBox(height: 8),

                  // Reject Button (Instead of Close)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleRejectCounterOffer(offer);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('offers.reject'.tr()),
                  ),
                ] else ...[
                  // Close Button (Only for Accept/Reject/Error cases)
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('common.close'.tr()),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Karşı teklifi kabul et
  Future<void> _handleAcceptCounterOffer(Offer offer) async {
    // Loading göster
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _offerService
          .acceptCounterOffer(offer)
          .timeout(const Duration(seconds: 10));

      // Loading kapat
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (result['success']) {
        if (mounted) {
          // 🎬 Animasyon göster
          await _playPurchaseAnimation();

          // İlanı kaldır (Marketten sil)
          _marketService.removeListing(_vehicle.id);

          // Kullanıcıyı güncelle
          await _loadCurrentUser();

          // Başarı dialogunu göster
          if (mounted && _currentUser != null) {
            _showPurchaseSuccessDialog(_currentUser!.balance);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 6,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.red.shade600,
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result['error'] ?? 'common.error'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Loading kapat
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 6,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red.shade600,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'errors.errorWithDetail'.trParams({'detail': e.toString()}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  /// Satın alma animasyonunu oynat
  Future<void> _playPurchaseAnimation() async {
    if (!mounted) return;

    // Dialog'u kapatmak için navigator'ı önceden al (Root navigator kullan)
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => PopScope(
        canPop: false, // Geri tuşunu devre dışı bırak
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dönen çekiç/tokmak animasyonu
              Lottie.asset(
                'assets/animations/buy_car.json',
                width: 300,
                height: 300,
                repeat: false, // Sadece 1 kez oynat
              ),
            ],
          ),
        ),
      ),
    );

    // Animasyon süresi kadar bekle (~2 saniye)
    await Future.delayed(const Duration(milliseconds: 2000));

    // Dialog'u kapat (mounted kontrolüne gerek yok çünkü navigator'ı capture ettik)
    navigator.pop();
  }

  /// Satın alma başarılı dialogunu göster
  void _showPurchaseSuccessDialog(double newBalance) {
    // Ekranı kapatmak için navigator'ı önceden al (Tab navigator)
    final screenNavigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glassmorphism Background
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        height: 110,
                      ), // Space for the floating image
                      // Congratulations Title
                      Text(
                        'purchase.congratulations'.tr(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Vehicle Name
                      Text(
                        _vehicle.fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Successfully Purchased Text
                      Text(
                        'purchase.successfullyPurchased'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Success Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.stars,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'purchase.successMessage'.tr(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${'purchase.newBalance'.tr()}: ${_formatCurrency(newBalance)} TL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Modern Gradient Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.deepPurple, Color(0xFF8E24AA)],
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
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            ); // Dialogu kapat (Root navigator)
                            screenNavigator.pop(
                              true,
                            ); // Ekranı kapat (Tab navigator)
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'purchase.great'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating Vehicle Image or Icon
            Positioned(
              top: 24,
              child: SizedBox(
                width: 150,
                height: 100,
                child: _vehicle.imageUrl != null
                    ? GameImage(
                        assetPath: _vehicle.imageUrl!,
                        fit: BoxFit.contain,
                      )
                    : const Icon(
                        Icons.directions_car,
                        size: 60,
                        color: Colors.deepPurple,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== XP SİSTEMİ METODLARI ==========

  /// XP kazanım animasyonu göster (overlay)
  void _showXPGainAnimationOverlay(XPGainResult result) {
    if (result.xpGained <= 0 || !mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10, // AppBar hizası
        left: 0,
        right: 0,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 800),
          tween: Tween<double>(begin: 0, end: 1),
          onEnd: () {
            Future.delayed(const Duration(seconds: 2), () async {
              entry.remove();
              // Level up varsa dialog göster
              if (result.leveledUp && mounted) {
                await _showLevelUpDialog(result);
              }
            });
          },
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple,
                            Colors.deepPurple.shade300,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
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
              ),
            );
          },
        ),
      ),
    );

    overlay.insert(entry);
  }

  /// Seviye atlama dialogu göster
  Future<void> _showLevelUpDialog(XPGainResult result) async {
    if (!mounted || result.rewards == null) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(reward: result.rewards!),
    );

    // Dialog kapandıktan sonra reklam göster
    await AdService().showInterstitialAd(force: true);
  }

  /// Karşı teklif gönderme dialogunu göster

  /// Karşı teklifi reddet
  Future<void> _handleRejectCounterOffer(Offer offer) async {
    // Loading göster
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _offerService.rejectCounterOffer(offer);

      // Loading kapat
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 6,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.orange.shade600,
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'offer.rejected'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 6,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.red.shade600,
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'common.error'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Loading kapat
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 6,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red.shade600,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
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
