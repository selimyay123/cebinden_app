import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart'; // 🆕 Input formatters için
import 'package:intl/intl.dart';
import '../models/offer_model.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import '../widgets/level_up_dialog.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/offer_service.dart';
import '../services/localization_service.dart';
import '../widgets/modern_alert_dialog.dart';
import '../services/xp_service.dart';
import '../utils/brand_colors.dart';
import '../services/market_refresh_service.dart'; // Araç detayları için
import '../models/vehicle_model.dart'; // Vehicle modeli için
import 'dart:math'; // Random için
import 'main_screen.dart';
import '../utils/vehicle_utils.dart';
import '../mixins/auto_refresh_mixin.dart';

import 'package:lottie/lottie.dart'; // 🆕 Animasyon için

import '../models/ai_buyer_model.dart';
import '../services/skill_service.dart';
import '../services/asset_service.dart';
import '../services/ad_service.dart';

class MyOffersScreen extends StatefulWidget {
  final int initialTab;
  final String?
  selectedBrand; // null = marka listesi göster, brand = o markanın tekliflerini göster
  final String?
  selectedVehicleId; // null = araç listesi göster, vehicleId = o aracın tekliflerini göster
  final bool isIncoming; // true = gelen teklifler, false = gönderilen teklifler

  const MyOffersScreen({
    Key? key,
    this.initialTab = 0,
    this.selectedBrand,
    this.selectedVehicleId,
    this.isIncoming = true,
  }) : super(key: key);

  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen>
    with SingleTickerProviderStateMixin, RouteAware, AutoRefreshMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();
  final OfferService _offerService = OfferService();
  final MarketRefreshService _marketService = MarketRefreshService();
  final AssetService _assetService = AssetService();

  // Gelen teklifler (kullanıcının ilanlarına gelen)
  List<Offer> _incomingOffers = [];
  Map<String, List<Offer>> _incomingOffersByVehicle = {};
  Map<String, List<Offer>> _incomingOffersByBrand = {}; // Markaya göre grupla

  bool _isLoading = true;
  bool _shouldRefreshParent =
      false; // Üst ekrana güncelleme sinyali göndermek için
  StreamSubscription? _offerUpdateSubscription;

  @override
  int? get tabIndex => 5; // MainScreen'deki index

  @override
  void refresh() {
    _loadOffers();
  }

  @override
  void initState() {
    super.initState();
    // Sadece marka seçilmemişse TabController oluştur
    /*
    if (widget.selectedBrand == null) {
      _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: widget.initialTab,
      );
    }
    */
    _initializeServices();
    _loadOffers();

    // Teklif güncellemelerini dinle (alt ekranlardan gelen değişimler için)
    _offerUpdateSubscription = _db.onOfferUpdate.listen((_) {
      _loadOffers();
    });
  }

  @override
  void dispose() {
    _offerUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await _assetService.init();
    if (mounted) setState(() {});
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Gelen teklifleri getir (kullanıcının ilanlarına gelen)
      _incomingOffers = await _db.getOffersBySellerId(currentUser.id);

      // Araca göre grupla
      _incomingOffersByVehicle = {};
      for (var offer in _incomingOffers) {
        if (!_incomingOffersByVehicle.containsKey(offer.vehicleId)) {
          _incomingOffersByVehicle[offer.vehicleId] = [];
        }
        _incomingOffersByVehicle[offer.vehicleId]!.add(offer);
      }

      // Markaya göre grupla (gelen teklifler) - SADECE BEKLEYENLERİ AL
      _incomingOffersByBrand = {};
      for (var offer in _incomingOffers) {
        // Sadece bekleyen (pending) ve gelen (isUserOffer == false) teklifleri ekle
        if (offer.isPending() && !offer.isUserOffer) {
          if (!_incomingOffersByBrand.containsKey(offer.vehicleBrand)) {
            _incomingOffersByBrand[offer.vehicleBrand] = [];
          }
          _incomingOffersByBrand[offer.vehicleBrand]!.add(offer);
        }
      }
    } catch (e) {}

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          Navigator.pop(context, _shouldRefreshParent);
          return false;
        }
        return true;
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // Eğer bir marka ve araç seçilmişse, o aracın tekliflerini göster
    if (widget.selectedBrand != null && widget.selectedVehicleId != null) {
      return _buildVehicleOffersScreen();
    }

    // Eğer sadece marka seçilmişse, o markanın araçlarını göster
    if (widget.selectedBrand != null) {
      return _buildVehicleListScreen();
    }

    // Aksi takdirde, tab view ile marka listelerini göster
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('offers.title'.tr()),
        actions: [],
        backgroundColor: Colors.deepPurple.withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 0,
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
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        // 🆕 Uyarı Mesajı
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          color: Colors.deepPurple.shade50.withValues(
                            alpha: 0.9,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'offers.limitWarning'.tr(),
                                  style: TextStyle(
                                    color: Colors.deepPurple.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _incomingOffersByBrand.isEmpty
                              ? _buildEmptyState()
                              : _buildBrandList(),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // Marka logosunu oluştur (Local veya Asset)
  Widget _buildBrandLogo(String brand, {double size = 120, Color? color}) {
    final assetPath = 'assets/images/brands/${brand.toLowerCase()}.png';
    final file = _assetService.getLocalFile(assetPath);

    if (file.existsSync()) {
      return Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.inbox, size: size * 0.8, color: color),
      );
    }

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.inbox, size: size * 0.8, color: color),
    );
  }

  // Marka listesi (Grid view)
  Widget _buildBrandList() {
    final brandMap = _incomingOffersByBrand;

    return RefreshIndicator(
      onRefresh: _loadOffers,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: brandMap.length,
        itemBuilder: (context, index) {
          final brand = brandMap.keys.elementAt(index);
          final offers = brandMap[brand]!;
          return _buildBrandCard(brand, offers.length);
        },
      ),
    );
  }

  // Marka kartı widget'ı
  Widget _buildBrandCard(String brand, int offerCount) {
    final brandColor = BrandColors.getColor(
      brand,
      defaultColor: Colors.deepPurple,
    );

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyOffersScreen(
              selectedBrand: brand,
              selectedVehicleId: null, // Önce araç seçimi
            ),
          ),
        );

        if (result == true && mounted) {
          _loadOffers();
          _shouldRefreshParent = true;
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Arkaplan dekoratif eleman
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.1,
                child: _buildBrandLogo(brand, size: 120, color: brandColor),
              ),
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge (Teklif Sayısı)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: brandColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$offerCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  // Marka İsmi
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: brandColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offerCount == 1
                            ? '1 ${'misc.offer'.tr()}'
                            : '$offerCount ${'misc.offers'.tr()}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Seçili markanın araçlarını gösteren ekran (YENİ ARA EKRAN)
  Widget _buildVehicleListScreen() {
    final brandOffers = _incomingOffersByBrand[widget.selectedBrand] ?? [];

    // Araca göre grupla
    Map<String, List<Offer>> offersByVehicle = {};
    for (var offer in brandOffers) {
      if (!offersByVehicle.containsKey(offer.vehicleId)) {
        offersByVehicle[offer.vehicleId] = [];
      }
      offersByVehicle[offer.vehicleId]!.add(offer);
    }

    // SADECE BEKLEYENLERİ FİLTRELE: Sadece bekleyen teklifi olan araçları göster
    Map<String, List<Offer>> activeVehicles = {};
    for (var entry in offersByVehicle.entries) {
      final vehicleOffers = entry.value;
      // En az 1 bekleyen teklif varsa bu aracı göster
      if (vehicleOffers.any((o) => o.isPending())) {
        activeVehicles[entry.key] = vehicleOffers;
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.selectedBrand} ${'offers.title'.tr()}'),
        actions: [],
        backgroundColor: Colors.deepPurple.withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 0,
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
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: activeVehicles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 80,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'myVehicles.noActiveOffers'.tr(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 2,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'myVehicles.noPendingOffersForBrand'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 2,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadOffers,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: activeVehicles.length,
                              itemBuilder: (context, index) {
                                final vehicleId = activeVehicles.keys.elementAt(
                                  index,
                                );
                                final offers = activeVehicles[vehicleId]!;
                                return _buildVehicleSelectionCard(
                                  vehicleId,
                                  offers,
                                );
                              },
                            ),
                          ),
                  ),
                ),
        ),
      ),
    );
  }

  // Seçili aracın tekliflerini gösteren ekran
  Widget _buildVehicleOffersScreen() {
    final brandOffers = _incomingOffersByBrand[widget.selectedBrand] ?? [];

    // Seçili aracın tekliflerini filtrele
    final vehicleOffers = brandOffers
        .where((offer) => offer.vehicleId == widget.selectedVehicleId)
        .toList();

    // Araç bilgisi için ilk teklifi al
    final firstOffer = vehicleOffers.isNotEmpty ? vehicleOffers.first : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          firstOffer != null
              ? '${firstOffer.vehicleBrand} ${firstOffer.vehicleModel}'
              : 'myVehicles.offers'.tr(),
        ),
        actions: [],
        backgroundColor: Colors.deepPurple.withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: _getBackgroundImageProvider(
              'assets/images/general_bg_dark.png',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: vehicleOffers.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadOffers,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                // Araç Bilgi Kartı
                                if (firstOffer != null)
                                  _buildVehicleInfoCard(firstOffer),
                                const SizedBox(height: 16),

                                // "Tüm Teklifleri Reddet" Butonu (Sadece gelen tekliflerde ve bekleyen teklif varsa)
                                if (vehicleOffers.any((o) => o.isPending()))
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Center(
                                      child: SizedBox(
                                        height: 36,
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _rejectAllOffers(vehicleOffers),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade50
                                                .withValues(alpha: 0.9),
                                            foregroundColor: Colors.red,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              side: BorderSide(
                                                color: Colors.red.shade200,
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.delete_sweep,
                                            size: 18,
                                          ),
                                          label: Text(
                                            'myVehicles.rejectAll'.tr(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Teklif Listesi
                                ...vehicleOffers.map((offer) {
                                  return _buildIncomingOfferCard(offer);
                                }).toList(),
                              ],
                            ),
                          ),
                  ),
                ),
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
            Icons.local_offer_outlined, // Changed icon to match style
            size: 80, // Adjusted size
            color: Colors.black,
          ),
          const SizedBox(height: 16),
          Text(
            'myVehicles.noIncomingOffers'.tr(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'myVehicles.noIncomingOffersDesc'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Araç seçimi kartı (YENİ) - Ara ekran için
  Widget _buildVehicleSelectionCard(String vehicleId, List<Offer> offers) {
    final firstOffer = offers.first;
    final pendingOffers = offers.where((o) => o.isPending()).toList();
    final acceptedOffers = offers
        .where((o) => o.status == OfferStatus.accepted)
        .toList();
    final rejectedOffers = offers
        .where((o) => o.status == OfferStatus.rejected)
        .toList();

    return Card(
      color: Colors.white.withValues(alpha: 0.9),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          // Araç teklifler ekranına git ve sonucu dinle
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyOffersScreen(
                selectedBrand: widget.selectedBrand,
                selectedVehicleId: vehicleId,
                isIncoming: widget.isIncoming,
                initialTab: widget.initialTab,
              ),
            ),
          );

          // Eğer teklifler silindi/değişti ise listeyi yenile
          if (result == true && mounted) {
            _loadOffers();
            _shouldRefreshParent = true;
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Araç Başlığı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  // Araç Resmi
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildVehicleImage(
                      firstOffer.vehicleImageUrl,
                      100,
                      75,
                      brand: firstOffer.vehicleBrand,
                      model: firstOffer.vehicleModel,
                      vehicleId: firstOffer.vehicleId,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Araç Bilgisi
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${firstOffer.vehicleBrand} ${firstOffer.vehicleModel}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${firstOffer.vehicleYear} ${'vehicles.model'.tr()}',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_formatCurrency(firstOffer.listingPrice)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Ok ikonu
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.deepPurple,
                    size: 24,
                  ),
                ],
              ),
            ),

            // Teklif İstatistikleri
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildStatChip(
                      'myVehicles.statusPending'.tr(),
                      pendingOffers.length,
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildStatChip(
                      'myVehicles.statusAccepted'.tr(),
                      acceptedOffers.length,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatChip(
                      'myVehicles.statusRejected'.tr(),
                      rejectedOffers.length,
                      Colors.red,
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

  // Araç bilgi kartı (Teklifler ekranı üstünde)
  Widget _buildVehicleInfoCard(Offer offer) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade50.withValues(alpha: 0.9),
              Colors.white.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Araç Resmi
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildVehicleImage(
                offer.vehicleImageUrl,
                120,
                90,
                brand: offer.vehicleBrand,
                model: offer.vehicleModel,
                vehicleId: offer.vehicleId,
              ),
            ),
            const SizedBox(width: 16),
            // Araç Bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${offer.vehicleBrand} ${offer.vehicleModel}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${offer.vehicleYear}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'misc.listingPriceLabel'.trParams({
                        'price': _formatCurrency(offer.listingPrice),
                      }),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  // Gelen teklif kartı - Chat Arayüzü
  Widget _buildIncomingOfferCard(Offer offer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Alıcı Mesajı (Sol - Gri Balon -> Mor Balon)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  offer.buyerName[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Mesaj Balonu
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İsim ve Zaman
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            offer.buyerName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getTimeAgo(offer.offerDate),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Balon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(
                          0.6,
                        ), // Mor arka plan
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mesaj Metni
                          if (offer.message != null)
                            Text(
                              offer.message!.tr(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white, // Beyaz yazı
                              ),
                            ),

                          const SizedBox(height: 8),
                          Divider(
                            height: 16,
                            color: Colors.white.withOpacity(0.2),
                          ),

                          // Teklif Fiyatı
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'offers.offerPrice'.tr() + ': ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                '${_formatCurrency(offer.offerPrice)} TL',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white, // Beyaz fiyat
                                ),
                              ),
                            ],
                          ),

                          // Kar/Zarar Analizi (FutureBuilder ile araç bilgisini çek)
                          FutureBuilder<UserVehicle?>(
                            future: _db.getUserVehicleById(offer.vehicleId),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data == null)
                                return const SizedBox();

                              final vehicle = snapshot.data!;
                              final profitLoss =
                                  offer.offerPrice - vehicle.purchasePrice;
                              final profitLossPercentage =
                                  (profitLoss / vehicle.purchasePrice) * 100;
                              final isProfit = profitLoss >= 0;
                              final color = isProfit
                                  ? Colors.greenAccent
                                  : Colors.redAccent; // Daha parlak renkler

                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: color.withOpacity(0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isProfit
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      size: 14,
                                      color: color,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${isProfit ? '+' : ''}${_formatCurrency(profitLoss)} TL',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                    Text(
                                      ' (%${profitLossPercentage.toStringAsFixed(1)})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: color.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40), // Sağdan boşluk
            ],
          ),

          // 2. Kullanıcı Cevabı (Sağ - Renkli Balon)
          if (!offer.isPending() || offer.counterOfferAmount != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 40), // Soldan boşluk
                // Mesaj Balonu
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Balon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getUserResponseColor(offer),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(4),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [_buildUserResponseContent(offer)],
                        ),
                      ),

                      // Durum (Okundu vs.)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 4),
                        child: Icon(
                          Icons.done_all,
                          size: 14,
                          color: _getUserResponseColor(
                            offer,
                          ).withOpacity(1.0), // Koyu ton
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          // 3. Aksiyon Butonları (Hızlı Cevap Barı)
          if (offer.isPending()) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(
                left: 48,
              ), // Avatar hizasından başla
              child: Row(
                children: [
                  // Kabul Et
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleAcceptOffer(offer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Icon(Icons.check, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Karşı Teklif
                  Expanded(
                    flex: 2, // Daha geniş
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showCounterOfferDialogForIncoming(offer, null),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: Text(
                        'offers.counter'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade50.withOpacity(
                          0.9,
                        ),
                        foregroundColor: Colors.deepPurple,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.deepPurple.withOpacity(0.5),
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Reddet
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleRejectOffer(offer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50.withOpacity(0.9),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Icon(Icons.close, size: 20),
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

  Color _getUserResponseColor(Offer offer) {
    if (offer.status == OfferStatus.accepted) return Colors.green.shade100;
    if (offer.status == OfferStatus.rejected) return Colors.red.shade100;
    if (offer.counterOfferAmount != null) return Colors.deepPurple.shade100;
    return Colors.blue.shade100;
  }

  Widget _buildUserResponseContent(Offer offer) {
    if (offer.status == OfferStatus.accepted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            'negotiation.accept.1'.tr(), // "Teklifiniz uygun, kabul ediyorum!"
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      );
    } else if (offer.status == OfferStatus.rejected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cancel, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Text(
            'negotiation.reject.1'.tr(), // "Maalesef bu fiyat çok düşük."
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      );
    } else if (offer.counterOfferAmount != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'negotiation.counter.3'.trParams({
              'amount': _formatCurrency(offer.counterOfferAmount!),
            }),
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildVehicleImage(
    String imageUrl,
    double width,
    double height, {
    String? brand,
    String? model,
    String? vehicleId,
  }) {
    // 1. URL boşsa veya null ise fallback dene
    if (imageUrl.isEmpty) {
      if (brand != null && model != null) {
        final fallbackPath = VehicleUtils.getVehicleImage(
          brand,
          model,
          vehicleId: vehicleId,
        );
        if (fallbackPath != null) {
          // Fallback path de indirilmiş olabilir mi?
          final file = _assetService.getLocalFile(fallbackPath);
          if (file.existsSync()) {
            return Image.file(
              file,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _buildGenericCarIcon(width, height),
            );
          }

          return Image.asset(
            fallbackPath,
            width: width,
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _buildGenericCarIcon(width, height),
          );
        }
      }
      return _buildGenericCarIcon(width, height);
    }

    // 2. HTTP URL ise (Network Image)
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (brand != null && model != null) {
            final fallbackPath = VehicleUtils.getVehicleImage(
              brand,
              model,
              vehicleId: vehicleId,
            );
            if (fallbackPath != null) {
              // Fallback path de indirilmiş olabilir mi?
              final file = _assetService.getLocalFile(fallbackPath);
              if (file.existsSync()) {
                return Image.file(
                  file,
                  width: width,
                  height: height,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildGenericCarIcon(width, height),
                );
              }

              return Image.asset(
                fallbackPath,
                width: width,
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildGenericCarIcon(width, height),
              );
            }
          }
          return _buildGenericCarIcon(width, height);
        },
      );
    }

    // 3. Local Asset veya İndirilmiş Dosya
    // Önce indirilmiş dosya var mı bak
    try {
      final file = _assetService.getLocalFile(imageUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildGenericCarIcon(width, height),
        );
      }
    } catch (e) {
      debugPrint('Error checking local vehicle asset: $e');
    }

    // Yoksa asset olarak dene
    return Image.asset(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        if (brand != null && model != null) {
          final fallbackPath = VehicleUtils.getVehicleImage(
            brand,
            model,
            vehicleId: vehicleId,
          );
          // Eğer fallback path farklıysa onu dene
          if (fallbackPath != null && fallbackPath != imageUrl) {
            // Fallback path de indirilmiş olabilir mi?
            final file = _assetService.getLocalFile(fallbackPath);
            if (file.existsSync()) {
              return Image.file(
                file,
                width: width,
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildGenericCarIcon(width, height),
              );
            }

            return Image.asset(
              fallbackPath,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _buildGenericCarIcon(width, height),
            );
          }
        }
        return _buildGenericCarIcon(width, height);
      },
    );
  }

  Widget _buildGenericCarIcon(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Icon(Icons.directions_car, size: width * 0.4, color: Colors.grey),
    );
  }

  Widget _buildOfferTile(Offer offer, {bool compact = false}) {
    final percentDiff = offer.offerPercentage;
    final isGoodOffer = percentDiff >= -10; // -%10'dan az düşük ise iyi teklif

    return FutureBuilder<UserVehicle?>(
      future: _db.getUserVehicleById(offer.vehicleId),
      builder: (context, snapshot) {
        final vehicle = snapshot.data;
        return _buildOfferTileContent(
          offer,
          vehicle,
          percentDiff,
          isGoodOffer,
          compact,
        );
      },
    );
  }

  Widget _buildOfferTileContent(
    Offer offer,
    UserVehicle? vehicle,
    double percentDiff,
    bool isGoodOffer,
    bool compact,
  ) {
    // Kar/Zarar hesaplama
    double? profitLoss;
    double? profitLossPercentage;

    if (vehicle != null) {
      profitLoss = offer.offerPrice - vehicle.purchasePrice;
      profitLossPercentage = (profitLoss / vehicle.purchasePrice) * 100;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getOfferBackgroundColor(offer),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getOfferBorderColor(offer), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: Alıcı ve Fiyat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Alıcı Bilgisi
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        offer.buyerName[0],
                        style: TextStyle(
                          color: Colors.deepPurple.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.buyerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _getTimeAgo(offer.offerDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Fiyat
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatCurrency(offer.offerPrice)} TL',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        percentDiff >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: percentDiff >= 0 ? Colors.green : Colors.red,
                      ),
                      Text(
                        '${percentDiff.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: percentDiff >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Kar/Zarar Analizi
          if (profitLoss != null && !compact) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: profitLoss >= 0
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: profitLoss >= 0
                      ? Colors.green.shade300
                      : Colors.red.shade300,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            profitLoss >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: profitLoss >= 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            profitLoss >= 0
                                ? 'misc.profit'.tr()
                                : 'misc.loss'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: profitLoss >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${profitLoss >= 0 ? '+' : ''}${_formatCurrency(profitLoss)} TL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: profitLoss >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'misc.profitLossRatio'.tr(),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      Text(
                        '${profitLossPercentage! >= 0 ? '+' : ''}${profitLossPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: profitLoss >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'misc.purchasePrice'.tr(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        '${_formatCurrency(vehicle!.purchasePrice)} TL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Mesaj
          if (offer.message != null && !compact) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      offer.message!.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Aksiyon Butonları (Sadece bekleyen teklifler için)
          if (offer.isPending() && !compact) ...[
            const SizedBox(height: 12),
            // Kabul Et Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleAcceptOffer(offer),
                icon: const Icon(Icons.check_circle, size: 20),
                label: Text('offers.accept'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Karşı Teklif Ver Butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _showCounterOfferDialogForIncoming(offer, vehicle),
                icon: const Icon(Icons.local_offer, size: 20),
                label: Text('offers.sendCounterOffer'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Reddet Butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _handleRejectOffer(offer),
                icon: const Icon(Icons.cancel, size: 20),
                label: Text('offers.reject'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],

          // Durum Badge (Kabul/Red edilmiş için)
          if (!offer.isPending()) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: offer.status == OfferStatus.accepted
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                offer.status == OfferStatus.accepted
                    ? 'misc.acceptedStatus'.tr()
                    : 'misc.rejectedStatus'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getOfferBackgroundColor(Offer offer) {
    if (offer.status == OfferStatus.accepted) {
      return Colors.green.shade50.withValues(alpha: 0.9);
    } else if (offer.status == OfferStatus.rejected) {
      return Colors.red.shade50.withValues(alpha: 0.9);
    } else if (offer.offerPercentage >= -10) {
      return Colors.deepPurple.shade50.withValues(alpha: 0.9);
    } else {
      return Colors.grey.shade50.withValues(alpha: 0.9);
    }
  }

  Color _getOfferBorderColor(Offer offer) {
    if (offer.status == OfferStatus.accepted) {
      return Colors.green;
    } else if (offer.status == OfferStatus.rejected) {
      return Colors.red;
    } else if (offer.offerPercentage >= -10) {
      return Colors.deepPurple;
    } else {
      return Colors.grey.shade300;
    }
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} ${'misc.daysAgo'.tr()}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${'misc.hoursAgo'.tr()}';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${'misc.minutesAgo'.tr()}';
    } else {
      return 'misc.justNow'.tr();
    }
  }

  String _formatCurrency(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  String _formatDate(DateTime date) {
    final currentLang = LocalizationService().currentLanguage;
    final locale = currentLang == 'tr' ? 'tr_TR' : 'en_US';
    return DateFormat('dd MMMM yyyy', locale).format(date);
  }

  Future<void> _handleAcceptOffer(Offer offer) async {
    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'misc.acceptOfferTitle'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${offer.buyerName} ${'offers.acceptConfirmMessage'.tr()}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'offers.offerPriceLabel'.tr(),
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                      Text(
                        '${_formatCurrency(offer.counterOfferAmount ?? offer.offerPrice)} TL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        buttonText: 'misc.acceptButton'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.check_circle,
        iconColor: Colors.green,
      ),
    );

    if (confirmed == true) {
      // 🎬 Satış animasyonunu oynat ve teklifi kabul et (paralel)
      final xpResult = await _playSellingAnimation(
        _offerService.acceptOffer(offer),
      );

      // 📺 Reklam Göster (Zorunlu)
      await AdService().showInterstitialAd();

      if (mounted) {
        if (xpResult != null) {
          // Başarı mesajı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text('offers.acceptSuccess'.tr()),
              backgroundColor: Colors.green.withOpacity(0.8),
            ),
          );

          // Level up varsa dialog göster
          if (xpResult.leveledUp) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => LevelUpDialog(reward: xpResult.rewards!),
            );

            // Dialog kapandıktan sonra reklam göster
            await AdService().showInterstitialAd();
          }

          // Listeyi yenile
          await _loadOffers();
          _shouldRefreshParent = true;

          // Eğer bu araç detay ekranında isek ve artık bekleyen teklif kalmadıysa, geri dön
          if (widget.selectedVehicleId != null) {
            final remainingOffers =
                _incomingOffersByVehicle[widget.selectedVehicleId] ?? [];
            final hasPendingOffers = remainingOffers.any((o) => o.isPending());

            if (!hasPendingOffers) {
              // Artık bekleyen teklif yok, en başa (marka listesine) dön
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        } else {
          // Hata mesajı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text('offers.acceptError'.tr()),
              backgroundColor: Colors.red.withOpacity(0.8),
            ),
          );
        }
      }
    }
  }

  /// Gönderilen teklif kartı - Chat Arayüzü
  Future<void> _handleAcceptCounterOffer(Offer offer) async {
    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'offer.acceptCounterTitle'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'offer.acceptCounterConfirmMessage'.trParams({
                'brand': offer.vehicleBrand,
                'model': offer.vehicleModel,
              }),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'offer.counterOfferLabel'.tr(),
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                      Text(
                        '${_formatCurrency(offer.counterOfferAmount!)} TL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.green),
                  Text(
                    'offer.garageInfo'.tr(),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'offer.balanceInfo'.trParams({
                      'amount': _formatCurrency(offer.counterOfferAmount!),
                    }),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        buttonText: 'offer.acceptButton'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.check_circle,
        iconColor: Colors.green,
      ),
    );

    if (confirmed == true) {
      // 🎬 Satış animasyonunu oynat ve teklifi kabul et (paralel)
      final result = await _playSellingAnimation(
        _offerService.acceptCounterOffer(offer),
      );

      // 📺 Reklam Göster (Zorunlu)
      await AdService().showInterstitialAd();

      if (mounted && result != null) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text('offer.counterOfferAcceptedSuccess'.tr()),
              backgroundColor: Colors.green.withOpacity(0.8),
            ),
          );
          _loadOffers();
          _shouldRefreshParent = true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text(
                result['error'] ?? 'purchase.insufficientBalance'.tr(),
              ),
              backgroundColor: Colors.red.withOpacity(0.8),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleRejectCounterOffer(Offer offer) async {
    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'offers.rejectCounterOfferTitle'.tr(),
        content: Text(
          'offers.rejectCounterOfferMessage'.trParams({
            'brand': offer.vehicleBrand,
            'model': offer.vehicleModel,
          }),
        ),
        buttonText: 'offer.rejectAndDelete'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.cancel,
        iconColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      final success = await _offerService.rejectCounterOffer(offer);

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            content: Text('offer.counterOfferRejectedSuccess'.tr()),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
        _loadOffers();
        _shouldRefreshParent = true;

        // Badge'i güncelle
        // _db.notifyOfferUpdate(); // DatabaseHelper artık otomatik yapıyor
      }
    }
  }

  // Tüm bekleyen teklifleri reddet (YENİ)
  Future<void> _rejectAllOffers(List<Offer> offers) async {
    // Sadece bekleyen teklifleri filtrele
    final pendingOffers = offers.where((o) => o.isPending()).toList();

    if (pendingOffers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          content: Text('misc.noPendingToReject'.tr()),
          backgroundColor: Colors.deepPurple.withOpacity(0.8),
        ),
      );
      return;
    }

    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'common.attention'.tr(),
        content: Text(
          '${'offers.rejectAllConfirm'.trParams({'count': pendingOffers.length.toString()})}\n\n${'offers.rejectAllWarning'.tr()}',
          style: const TextStyle(fontSize: 15),
        ),
        buttonText: 'myVehicles.rejectAll'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.warning,
        iconColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      // Loading göster
      _showLoadingDialog();

      // Tüm teklifleri reddet
      int successCount = 0;

      for (var offer in pendingOffers) {
        bool success = await _offerService.rejectOffer(offer);
        if (success) successCount++;
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Loading'i kapat

        if (successCount == pendingOffers.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text(
                '✅ ${'offers.rejectAllSuccess'.trParams({'count': successCount.toString()})}',
              ),
              backgroundColor: Colors.green.withOpacity(0.8),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text(
                '⚠️ ${'offers.rejectAllPartialSuccess'.trParams({'count': successCount.toString(), 'total': pendingOffers.length.toString()})}',
              ),
              backgroundColor: Colors.deepPurple.withOpacity(0.8),
            ),
          );
        }

        // Listeyi yenile
        await _loadOffers();
        _shouldRefreshParent = true;

        // Badge'i güncelle
        // _db.notifyOfferUpdate(); // DatabaseHelper artık otomatik yapıyor

        // Eğer tüm bekleyen teklifler silindiyse, en başa (marka listesine) dön
        if (successCount > 0 && widget.selectedVehicleId != null) {
          // Araç detay ekranındayız, en başa dön
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    }
  }

  Future<void> _handleRejectOffer(Offer offer) async {
    // Onay dialogu göster
    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'offer.rejectTitle'.tr(),
        content: Text(
          '${offer.buyerName} ${_formatCurrency(offer.offerPrice)} ${'common.currency'.tr()} ${'offers.rejectConfirmMessage'.tr()}\n\n${'offer.rejectWarning'.tr()}',
        ),
        buttonText: 'offer.rejectAndDelete'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.cancel,
        iconColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      // Loading göster
      _showLoadingDialog();

      bool success = await _offerService.rejectOffer(offer);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Loading'i kapat

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text('✅ ${'offer.rejectSuccess'.tr()}'),
              backgroundColor: Colors.green.withOpacity(0.8),
              duration: const Duration(milliseconds: 1500),
            ),
          );

          // Listeyi yenile
          await _loadOffers();
          _shouldRefreshParent = true;

          // Badge'i güncelle
          // _db.notifyOfferUpdate(); // DatabaseHelper artık otomatik yapıyor

          // Eğer bu araç detay ekranında isek ve artık bekleyen teklif kalmadıysa, geri dön
          if (widget.selectedVehicleId != null) {
            final remainingOffers =
                _incomingOffersByVehicle[widget.selectedVehicleId] ?? [];
            final hasPendingOffers = remainingOffers.any((o) => o.isPending());

            if (!hasPendingOffers) {
              // Artık bekleyen teklif yok, en başa (marka listesine) dön
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text('offers.acceptError'.tr()),
              backgroundColor: Colors.red.withOpacity(0.8),
            ),
          );
        }
      }
    }
  }

  /// Satın alma animasyonunu oynat
  Future<void> _playPurchaseAnimation() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => PopScope(
        canPop: false, // Geri tuşunu devre dışı bırak
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dönen çekiç/tokmak animasyonu
              Lottie.asset(
                'assets/animations/satinal.json',
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

    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // Animasyon overlay'ini kapat
    }
  }

  /// Satış animasyonunu oynat (YENİ)
  Future<T?> _playSellingAnimation<T>(Future<T> work) async {
    if (!mounted) return null;

    T? result;
    bool workDone = false;

    // İşlemi başlat
    final workFuture = work.then((value) {
      result = value;
      workDone = true;
      return value;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // İşlem bittiğinde diyalogu güncellemek için periyodik kontrol
          if (!workDone) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) setDialogState(() {});
            });
          }

          return PopScope(
            canPop: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Satış animasyonu
                  Lottie.asset(
                    'assets/animations/selling_car.json',
                    width: 300,
                    height: 300,
                    repeat: false,
                  ),
                  const SizedBox(height: 20),
                  // Eğer animasyon bitmiş ama iş hala devam ediyorsa loader göster
                  if (!workDone) ...[
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'offers.processing'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );

    // En az 2 saniye animasyon için bekle
    final animationDelay = Future.delayed(const Duration(milliseconds: 2000));

    // Hem animasyonun hem de işin bitmesini bekle
    await Future.wait([animationDelay, workFuture]);

    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // Animasyon overlay'ini kapat
    }

    return result;
  }

  /// Şık bir loading dialogu göster
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
                const SizedBox(height: 20),
                Text(
                  'offers.processing'.tr(),
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Satın alma başarılı dialogunu göster
  void _showPurchaseSuccessDialog(Offer offer, double newBalance) {
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
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        height: 80,
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
                        '${offer.vehicleBrand} ${offer.vehicleModel}',
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
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.2),
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
                                  'This vehicle is now yours!',
                                  style: TextStyle(
                                    fontSize: 15,
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
                                fontSize: 14,
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
                              color: Colors.deepPurple.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).pop();
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
              top: 0,
              child: SizedBox(
                width: 150,
                height: 100,
                child: offer.vehicleImageUrl.isNotEmpty
                    ? Image.asset(offer.vehicleImageUrl, fit: BoxFit.contain)
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

  /// Karşı teklif gönderme dialogunu göster

  /// Gelen teklife karşı teklif gönderme dialogunu göster
  Future<void> _showCounterOfferDialogForIncoming(
    Offer offer,
    UserVehicle? vehicle,
  ) async {
    // Eğer araç bilgisi yoksa (Chat ekranından geliyorsa), veritabanından çek
    UserVehicle? targetVehicle = vehicle;
    if (targetVehicle == null) {
      targetVehicle = await _db.getUserVehicleById(offer.vehicleId);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _CounterOfferDialog(
        offer: offer,
        vehicle: targetVehicle,
        onSend: (double amount) {
          _submitCounterOfferForIncoming(offer, amount);
        },
      ),
    );
  }

  /// Gelen teklife karşı teklif gönder
  Future<void> _submitCounterOfferForIncoming(
    Offer originalOffer,
    double counterOfferAmount,
  ) async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _offerService.sendCounterOfferToIncomingOffer(
        originalOffer: originalOffer,
        counterOfferAmount: counterOfferAmount,
      );

      // Loading kapat
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (!result['success']) {
        throw Exception(result['error'] ?? 'Unknown error');
      }

      // Karar kontrolü
      final decision = result['decision'] as String;

      if (decision == 'accept') {
        // ✅ KABUL EDİLDİ: Animasyon ve SnackBar göster

        // Animasyonu oynat (Fake bir future ile)
        await _playSellingAnimation(Future.value(true));

        if (mounted) {
          // Başarı mesajı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text('offer.counterOfferAcceptedSuccess'.tr()),
              backgroundColor: Colors.green.withOpacity(0.8),
            ),
          );
        }
      } else {
        // ❌ RED veya YENİ TEKLİF: Sonuç dialogunu göster
        if (mounted) {
          _showCounterOfferResultDialogForIncoming(result, originalOffer);
        }
      }

      // Listeyi yenile
      _loadOffers();
    } catch (e) {
      // Loading kapat
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            content: Text('offers.counterOfferError'.tr()),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
    }
  }

  /// Gelen teklife karşı teklif sonuç dialogunu göster
  void _showCounterOfferResultDialogForIncoming(
    Map<String, dynamic> result,
    Offer originalOffer,
  ) {
    final decision = result['decision'] as String;
    final response = result['response'] as String;
    final newCounterOffer = result['counterOffer'] as double?;

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
      iconColor = Colors.deepPurple;
      title = 'offer.counterOffer'.tr();
    }

    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'offers.buyerResponse'.tr(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              response.startsWith('offerService.')
                  ? (decision == 'counter' && newCounterOffer != null
                        ? response.trParams({
                            'amount': _formatCurrency(newCounterOffer),
                          })
                        : response.tr())
                  : response,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            if (newCounterOffer != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'offer.newCounterOffer'.tr(),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '${_formatCurrency(newCounterOffer)} TL',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.lightBlueAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      decision == 'accept'
                          ? 'offers.acceptSuccess'.tr()
                          : decision == 'reject'
                          ? 'offer.buyerRejectedMessage'.tr()
                          : 'offer.negotiationContinueMessage'.tr(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        icon: icon,
        iconColor: iconColor,
        customActions: [
          if (decision == 'counter' && newCounterOffer != null) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 3. Kabul Et (En üstte, en belirgin)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      // Yeni tutarı teklife işle
                      final updatedOffer = originalOffer.copyWith(
                        counterOfferAmount: newCounterOffer,
                      );
                      _handleAcceptCounterOffer(updatedOffer);
                    },
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: Text('offers.accept'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 2. Karşı Teklif Ver
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      // Yeni tutarı teklife işle
                      final updatedOffer = originalOffer.copyWith(
                        counterOfferAmount: newCounterOffer,
                      );
                      _showCounterOfferDialogForIncoming(updatedOffer, null);
                    },
                    icon: const Icon(Icons.local_offer, size: 20),
                    label: Text('offers.sendCounterOffer'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 1. Reddet
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      // Yeni tutarı teklife işle
                      final updatedOffer = originalOffer.copyWith(
                        counterOfferAmount: newCounterOffer,
                      );
                      _handleRejectCounterOffer(updatedOffer);
                    },
                    icon: const Icon(Icons.cancel, size: 20),
                    label: Text('offers.reject'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('common.ok'.tr()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Karşı teklifi kabul et ve satın alma işlemini yap
  Future<bool> _acceptCounterOffer(Offer offer, User user) async {
    try {
      // 1. Bakiyeyi düş
      final newBalance = user.balance - offer.counterOfferAmount!;
      bool balanceUpdated = await _db.updateUser(user.id, {
        'balance': newBalance,
      });
      if (!balanceUpdated) return false;

      // 2. Teklifi kabul edildi olarak işaretle
      bool offerUpdated = await _db.updateOfferStatus(
        offer.offerId,
        OfferStatus.accepted,
      );
      if (!offerUpdated) {
        // Rollback
        await _db.updateUser(user.id, {'balance': user.balance});
        return false;
      }

      // Aracı bulmaya çalış (MarketRefreshService'den)
      final marketService = MarketRefreshService();
      final activeListings = marketService.getActiveListings();
      Vehicle? sourceVehicle;

      try {
        sourceVehicle = activeListings.firstWhere(
          (v) => v.id == offer.vehicleId,
        );
      } catch (e) {
        sourceVehicle = null;
      }

      // Fallback değerler
      final random = Random();
      final colors = [
        'Beyaz',
        'Siyah',
        'Gri',
        'Kırmızı',
        'Mavi',
        'Gümüş',
        'Kahverengi',
        'Yeşil',
      ];
      final fuelTypes = ['Benzin', 'Dizel', 'Hybrid'];
      final transmissions = ['Manuel', 'Otomatik'];
      final engineSizes = ['1.0', '1.2', '1.4', '1.6', '2.0'];

      // 3. Aracı kullanıcıya ekle
      final userVehicle = UserVehicle.purchase(
        userId: user.id,
        vehicleId: offer.vehicleId,
        brand: offer.vehicleBrand,
        model: offer.vehicleModel,
        year: offer.vehicleYear,
        mileage: sourceVehicle?.mileage ?? (10000 + random.nextInt(190000)),
        purchasePrice: offer.counterOfferAmount!,
        color: sourceVehicle?.color ?? colors[random.nextInt(colors.length)],
        fuelType:
            sourceVehicle?.fuelType ??
            fuelTypes[random.nextInt(fuelTypes.length)],
        transmission:
            sourceVehicle?.transmission ??
            transmissions[random.nextInt(transmissions.length)],
        engineSize:
            sourceVehicle?.engineSize ??
            engineSizes[random.nextInt(engineSizes.length)],
        driveType: sourceVehicle?.driveType ?? 'Önden',
        hasWarranty: sourceVehicle?.hasWarranty ?? false,
        hasAccidentRecord: sourceVehicle?.hasAccidentRecord ?? false,
        score: sourceVehicle?.score ?? 75,
        bodyType: sourceVehicle?.bodyType ?? 'Sedan',
        horsepower: sourceVehicle?.horsepower ?? 100,
        imageUrl: offer.vehicleImageUrl,
      );

      bool vehicleAdded = await _db.addUserVehicle(userVehicle);
      if (!vehicleAdded) {
        // Rollback
        await _db.updateUser(user.id, {'balance': user.balance});
        await _db.updateOfferStatus(offer.offerId, OfferStatus.pending);
        return false;
      }

      // Badge'i güncelle
      // _db.notifyOfferUpdate(); // DatabaseHelper artık otomatik yapıyor

      return true;
    } catch (e) {
      return false;
    }
  }

  ImageProvider _getBackgroundImageProvider(String assetPath) {
    try {
      // 1. Önce indirilmiş dosyalara bak
      final file = _assetService.getLocalFile(assetPath);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (e) {
      debugPrint('Error checking local asset: $e');
    }

    // 2. Yoksa varsayılan (açık tema) görseli kullan (Fallback)
    // Eğer koyu tema görseli assets içinde yoksa, açık tema görselini kullan
    // Bu sayede uygulama çökmez.
    if (assetPath.contains('general_bg_dark.png')) {
      // Koyu tema görseli bulunamadıysa açık tema görselini dene
      return const AssetImage('assets/images/general_bg.png');
    }

    return AssetImage(assetPath);
  }
}

/// Binlik ayırıcı input formatter (Teklif Ver gibi)

class _CounterOfferDialog extends StatefulWidget {
  final Offer offer;
  final UserVehicle? vehicle;
  final Function(double amount) onSend;

  const _CounterOfferDialog({
    required this.offer,
    this.vehicle,
    required this.onSend,
  });

  @override
  State<_CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<_CounterOfferDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _amountController;
  final _formKey = GlobalKey<FormState>();
  double _acceptanceChance = 0.0;
  double _sweetTalkBonus = 0.0;
  User? _currentUser;
  final AuthService _authService = AuthService();
  final SkillService _skillService = SkillService();
  late AIBuyer _aiBuyer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _aiBuyer = AIBuyer.generateRandom(seed: widget.offer.offerId.hashCode);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadBonus();
  }

  Future<void> _loadBonus() async {
    _currentUser = await _authService.getCurrentUser();
    if (_currentUser != null) {
      final level = _skillService.getSkillLevel(
        _currentUser!,
        SkillService.skillSweetTalk,
      );
      _sweetTalkBonus = SkillService.sweetTalkBonuses[level] ?? 0.0;
    }
    _updateAcceptanceChance(_amountController.text);
  }

  void _updateAcceptanceChance(String value) {
    final cleanedText = value.replaceAll('.', '');
    final offerAmount = double.tryParse(cleanedText);
    if (offerAmount != null) {
      setState(() {
        _acceptanceChance = _aiBuyer.calculateAcceptanceChance(
          counterOfferAmount: offerAmount,
          originalOfferPrice: widget.offer.offerPrice,
          listingPrice: widget.offer.listingPrice,
          sweetTalkBonus: _sweetTalkBonus,
        );
      });
    } else {
      setState(() {
        _acceptanceChance = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final minOffer = widget.offer.offerPrice;
    final maxOffer = widget.offer.listingPrice;

    // Dinamik Kar/Zarar Hesabı
    double currentPrice = 0;
    try {
      currentPrice = double.parse(_amountController.text.replaceAll('.', ''));
    } catch (e) {
      currentPrice = 0;
    }

    double? profit;
    double? profitPercent;
    bool isProfit = false;

    if (widget.vehicle != null) {
      profit = currentPrice - widget.vehicle!.purchasePrice;
      isProfit = profit >= 0;
      profitPercent = widget.vehicle!.purchasePrice > 0
          ? (profit / widget.vehicle!.purchasePrice) * 100
          : 0;
    }

    return ModernAlertDialog(
      title: 'offers.counterOfferDialogTitle'.tr(),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.vehicle != null) ...[
                Row(
                  children: [
                    Text(
                      'vehicles.purchasePrice'.tr() + ': ',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_formatCurrency(widget.vehicle!.purchasePrice)} TL',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                '${widget.offer.vehicleBrand} ${widget.offer.vehicleModel}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    // Alıcının Teklifi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'offers.buyerOffer'.tr(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Text(
                            '${_formatCurrency(minOffer)} TL',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12, color: Colors.white24),
                    // İlan Fiyatı
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'vehicles.listingPrice'.tr(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${_formatCurrency(maxOffer)} TL',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🆕 Probability Bar (Gradient with Slider)
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
                        '%${(_acceptanceChance * 100).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _acceptanceChance > 0.7
                              ? Colors.greenAccent
                              : (_acceptanceChance > 0.3
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
                        color: Colors.white.withOpacity(0.3),
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
                            (_acceptanceChance * 2) -
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
                                color: _acceptanceChance > 0.7
                                    ? Colors.green
                                    : (_acceptanceChance > 0.3
                                          ? Colors.orange
                                          : Colors.red),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
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

              // Dinamik Kar/Zarar Göstergesi
              if (_amountController.text.isNotEmpty && profit != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isProfit
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isProfit
                          ? Colors.green.withOpacity(0.5)
                          : Colors.red.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isProfit ? Icons.trending_up : Icons.trending_down,
                        color: isProfit ? Colors.greenAccent : Colors.redAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${isProfit ? 'offer.profit'.tr() : 'offer.loss'.tr()}: ${_formatCurrency(profit.abs())} ${'common.currency'.tr()} (%${profitPercent!.abs().toStringAsFixed(1)})',
                          style: TextStyle(
                            color: isProfit
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Karşı Teklif Girişi
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ThousandsSeparatorInputFormatter(),
                ],
                onChanged: (value) {
                  _updateAcceptanceChance(value);
                },
                decoration: InputDecoration(
                  labelText: 'offers.yourCounterOffer'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText:
                      '${_formatCurrency(minOffer)} - ${_formatCurrency(maxOffer)} TL',
                  hintStyle: const TextStyle(color: Colors.white38),
                  suffixText: 'common.currency'.tr(),
                  suffixStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  prefixIcon: const Icon(Icons.money, color: Colors.white70),
                  helperText: 'offer.counterOfferInputHelper'.tr(),
                  helperMaxLines: 2,
                  helperStyle: const TextStyle(color: Colors.white54),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'offer.enterAmountError'.tr();
                  }
                  final price = double.tryParse(value.replaceAll('.', ''));
                  if (price == null || price <= 0) {
                    return 'offer.invalidAmountError'.tr();
                  }
                  if (price <= minOffer || price >= maxOffer) {
                    return 'offers.counterOfferRangeError'.tr();
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      buttonText: 'offer.sendOffer'.tr(),
      onPressed: () {
        if (_formKey.currentState!.validate()) {
          Navigator.of(context, rootNavigator: true).pop();
          final newOffer = double.parse(
            _amountController.text.replaceAll('.', ''),
          );
          widget.onSend(newOffer);
        }
      },
      secondaryButtonText: 'common.cancel'.tr(),
      onSecondaryPressed: () =>
          Navigator.of(context, rootNavigator: true).pop(),
    );
  }
}

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
