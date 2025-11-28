import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/offer_model.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/offer_service.dart';
import '../services/localization_service.dart';
import '../utils/brand_colors.dart';

class MyOffersScreen extends StatefulWidget {
  final int initialTab;
  final String? selectedBrand; // null = marka listesi göster, brand = o markanın tekliflerini göster
  final String? selectedVehicleId; // null = araç listesi göster, vehicleId = o aracın tekliflerini göster
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
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();
  final OfferService _offerService = OfferService();

  TabController? _tabController;

  // Gelen teklifler (kullanıcının ilanlarına gelen)
  List<Offer> _incomingOffers = [];
  Map<String, List<Offer>> _incomingOffersByVehicle = {};
  Map<String, List<Offer>> _incomingOffersByBrand = {}; // Markaya göre grupla

  // Gönderilen teklifler (kullanıcının gönderdiği)
  List<Offer> _sentOffers = [];
  Map<String, List<Offer>> _sentOffersByBrand = {}; // Markaya göre grupla

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Sadece marka seçilmemişse TabController oluştur
    if (widget.selectedBrand == null) {
      _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: widget.initialTab,
      );
    }
    _loadOffers();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
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
        // Sadece bekleyen (pending) teklifleri ekle
        if (offer.isPending) {
          if (!_incomingOffersByBrand.containsKey(offer.vehicleBrand)) {
            _incomingOffersByBrand[offer.vehicleBrand] = [];
          }
          _incomingOffersByBrand[offer.vehicleBrand]!.add(offer);
        }
      }

      // Gönderilen teklifleri getir (kullanıcının gönderdiği)
      _sentOffers = await _db.getOffersByBuyerId(currentUser.id);
      
      // Markaya göre grupla (gönderilen teklifler)
      _sentOffersByBrand = {};
      for (var offer in _sentOffers) {
        if (!_sentOffersByBrand.containsKey(offer.vehicleBrand)) {
          _sentOffersByBrand[offer.vehicleBrand] = [];
        }
        _sentOffersByBrand[offer.vehicleBrand]!.add(offer);
      }
    } catch (e) {
      
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('offers.title'.tr()),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController!,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.inbox),
              text: 'offers.incoming'.tr(),
            ),
            Tab(
              icon: const Icon(Icons.send),
              text: 'offers.sent'.tr(),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController!,
              children: [
                // Gelen Teklifler - Marka Listesi
                _incomingOffers.isEmpty
                    ? _buildEmptyState(isIncoming: true)
                    : _buildBrandList(isIncoming: true),

                // Gönderilen Teklifler - Marka Listesi
                _sentOffers.isEmpty
                    ? _buildEmptyState(isIncoming: false)
                    : _buildBrandList(isIncoming: false),
              ],
            ),
    );
  }

  // Marka listesi (Grid view)
  Widget _buildBrandList({required bool isIncoming}) {
    final brandMap = isIncoming ? _incomingOffersByBrand : _sentOffersByBrand;
    
    return RefreshIndicator(
      onRefresh: _loadOffers,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: brandMap.length,
        itemBuilder: (context, index) {
          final brand = brandMap.keys.elementAt(index);
          final offers = brandMap[brand]!;
          return _buildBrandCard(brand, offers.length, isIncoming);
        },
      ),
    );
  }

  // Marka kartı widget'ı
  Widget _buildBrandCard(String brand, int offerCount, bool isIncoming) {
    final brandColor = BrandColors.getColor(brand, defaultColor: Colors.deepOrange);
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyOffersScreen(
              selectedBrand: brand,
              selectedVehicleId: null, // Önce araç seçimi
              isIncoming: isIncoming,
              initialTab: isIncoming ? 0 : 1,
            ),
          ),
        );
      },
      child: Container(
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
        child: Stack(
          children: [
            // Arkaplan dekoratif eleman
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                isIncoming ? Icons.inbox : Icons.send,
                size: 100,
                color: brandColor.withOpacity(0.1),
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
                          ? '1 teklif' 
                          : '$offerCount teklif',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
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
    );
  }

  // Seçili markanın araçlarını gösteren ekran (YENİ ARA EKRAN)
  Widget _buildVehicleListScreen() {
    final isIncoming = widget.isIncoming;
    final brandOffers = isIncoming 
        ? _incomingOffersByBrand[widget.selectedBrand] ?? []
        : _sentOffersByBrand[widget.selectedBrand] ?? [];
    
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
      if (vehicleOffers.any((o) => o.isPending)) {
        activeVehicles[entry.key] = vehicleOffers;
      }
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('${widget.selectedBrand} Araçlarım'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeVehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aktif Teklif Yok',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bu markada bekleyen teklifi olan araç bulunmuyor',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
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
                      final vehicleId = activeVehicles.keys.elementAt(index);
                      final offers = activeVehicles[vehicleId]!;
                      return _buildVehicleSelectionCard(vehicleId, offers);
                    },
                  ),
                ),
    );
  }

  // Seçili aracın tekliflerini gösteren ekran
  Widget _buildVehicleOffersScreen() {
    final isIncoming = widget.isIncoming;
    final brandOffers = isIncoming 
        ? _incomingOffersByBrand[widget.selectedBrand] ?? []
        : _sentOffersByBrand[widget.selectedBrand] ?? [];
    
    // Seçili aracın tekliflerini filtrele
    final vehicleOffers = brandOffers.where((offer) => 
      offer.vehicleId == widget.selectedVehicleId
    ).toList();
    
    // Araç bilgisi için ilk teklifi al
    final firstOffer = vehicleOffers.isNotEmpty ? vehicleOffers.first : null;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(firstOffer != null 
          ? '${firstOffer.vehicleBrand} ${firstOffer.vehicleModel}'
          : 'Teklifler'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : vehicleOffers.isEmpty
              ? _buildEmptyState(isIncoming: isIncoming)
              : RefreshIndicator(
                  onRefresh: _loadOffers,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Araç Bilgi Kartı
                      if (firstOffer != null) _buildVehicleInfoCard(firstOffer),
                      const SizedBox(height: 16),
                      
                      // "Tüm Teklifleri Reddet" Butonu (Sadece gelen tekliflerde ve bekleyen teklif varsa)
                      if (isIncoming && vehicleOffers.any((o) => o.isPending))
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ElevatedButton.icon(
                            onPressed: () => _rejectAllOffers(vehicleOffers),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.cancel, size: 24),
                            label: const Text(
                              'Tüm Teklifleri Reddet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      
                      // Teklif Listesi
                      ...vehicleOffers.map((offer) {
                        if (isIncoming) {
                          return _buildIncomingOfferCard(offer);
                        } else {
                          return _buildSentOfferCard(offer);
                        }
                      }).toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState({required bool isIncoming}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isIncoming ? Icons.inbox_outlined : Icons.send_outlined,
            size: 120,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            isIncoming ? 'offers.noIncoming'.tr() : 'offers.noSent'.tr(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isIncoming
                ? 'offers.noIncomingDesc'.tr()
                : 'offers.noSentDesc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Araç seçimi kartı (YENİ) - Ara ekran için
  Widget _buildVehicleSelectionCard(String vehicleId, List<Offer> offers) {
    final firstOffer = offers.first;
    final pendingOffers = offers.where((o) => o.isPending).toList();
    final acceptedOffers = offers.where((o) => o.status == OfferStatus.accepted).toList();
    final rejectedOffers = offers.where((o) => o.status == OfferStatus.rejected).toList();

    return Card(
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
                color: Colors.deepOrange.shade50,
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
                    child: Image.network(
                      firstOffer.vehicleImageUrl,
                      width: 100,
                      height: 75,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 75,
                          color: Colors.grey[300],
                          child: const Icon(Icons.directions_car, size: 40, color: Colors.grey),
                        );
                      },
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
                          '${firstOffer.vehicleYear} Model',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
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
                    color: Colors.deepOrange,
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
                  _buildStatChip('Bekleyen', pendingOffers.length, Colors.orange),
                  _buildStatChip('Kabul', acceptedOffers.length, Colors.green),
                  _buildStatChip('Red', rejectedOffers.length, Colors.red),
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
            colors: [Colors.deepOrange.shade50, Colors.white],
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
              child: Image.network(
                offer.vehicleImageUrl,
                width: 120,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 90,
                    color: Colors.grey[300],
                    child: const Icon(Icons.directions_car, size: 50, color: Colors.grey),
                  );
                },
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
                      color: Colors.deepOrange,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${offer.vehicleYear}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepOrange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'İlan: ${_formatCurrency(offer.listingPrice)}',
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

  // Gelen teklif kartı - Tek bir teklif detayı
  Widget _buildIncomingOfferCard(Offer offer) {
    return _buildOfferTile(offer);
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
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOfferTile(Offer offer, {bool compact = false}) {
    final percentDiff = offer.offerPercentage;
    final isGoodOffer = percentDiff >= -10; // -%10'dan az düşük ise iyi teklif

    return FutureBuilder<UserVehicle?>(
      future: _db.getUserVehicleById(offer.vehicleId),
      builder: (context, snapshot) {
        final vehicle = snapshot.data;
        return _buildOfferTileContent(offer, vehicle, percentDiff, isGoodOffer, compact);
      },
    );
  }

  Widget _buildOfferTileContent(Offer offer, UserVehicle? vehicle, double percentDiff, bool isGoodOffer, bool compact) {
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
        border: Border.all(
          color: _getOfferBorderColor(offer),
          width: 1.5,
        ),
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
                      backgroundColor: Colors.deepOrange.shade100,
                      child: Text(
                        offer.buyerName[0],
                        style: TextStyle(
                          color: Colors.deepOrange.shade700,
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
                    '${_formatCurrency(offer.offerPrice)} ₺',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        percentDiff >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
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
                color: profitLoss >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: profitLoss >= 0 ? Colors.green.shade300 : Colors.red.shade300,
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
                            profitLoss >= 0 ? Icons.trending_up : Icons.trending_down,
                            color: profitLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            profitLoss >= 0 ? 'Kar' : 'Zarar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: profitLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${profitLoss >= 0 ? '+' : ''}${_formatCurrency(profitLoss)} ₺',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: profitLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kar/Zarar Oranı:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${profitLossPercentage! >= 0 ? '+' : ''}${profitLossPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: profitLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Satın Alma Fiyatı:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${_formatCurrency(vehicle!.purchasePrice)} ₺',
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
                      offer.message!,
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
          if (offer.isPending && !compact) ...[
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
                onPressed: () => _showCounterOfferDialogForIncoming(offer),
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
          if (!offer.isPending) ...[
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
                offer.status == OfferStatus.accepted ? 'KABUL EDİLDİ ✓' : 'REDDEDİLDİ ✗',
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
      return Colors.green.shade50;
    } else if (offer.status == OfferStatus.rejected) {
      return Colors.red.shade50;
    } else if (offer.offerPercentage >= -10) {
      return Colors.orange.shade50;
    } else {
      return Colors.grey.shade50;
    }
  }

  Color _getOfferBorderColor(Offer offer) {
    if (offer.status == OfferStatus.accepted) {
      return Colors.green;
    } else if (offer.status == OfferStatus.rejected) {
      return Colors.red;
    } else if (offer.offerPercentage >= -10) {
      return Colors.orange;
    } else {
      return Colors.grey.shade300;
    }
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} gün önce';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} saat önce';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} dakika önce';
    } else {
      return 'Şimdi';
    }
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
  }

  Future<void> _handleAcceptOffer(Offer offer) async {
    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teklifi Kabul Et'),
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
                      Text('offers.offerPriceLabel'.tr()),
                      Text(
                        '${_formatCurrency(offer.offerPrice)} ₺',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text(
                    'Bu teklifi kabul ederseniz:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('• Bakiyenize ${_formatCurrency(offer.offerPrice)} ₺ eklenecek'),
                  Text('offers.vehicleSold'.tr()),
                  Text('offers.otherOffersRejected'.tr()),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Kabul Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Teklifi kabul et
      bool success = await _offerService.acceptOffer(offer);

      if (mounted) {
        Navigator.pop(context); // Loading'i kapat

        if (success) {
          // Başarı mesajı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('offers.acceptSuccess'.tr()),
              backgroundColor: Colors.green,
            ),
          );

          // Listeyi yenile
          await _loadOffers();
          
          // Eğer bu araç detay ekranında isek ve artık bekleyen teklif kalmadıysa, geri dön
          if (widget.selectedVehicleId != null) {
            final remainingOffers = _incomingOffersByVehicle[widget.selectedVehicleId] ?? [];
            final hasPendingOffers = remainingOffers.any((o) => o.isPending);
            
            if (!hasPendingOffers) {
              // Artık bekleyen teklif yok, araç listesine dön ve güncelleme sinyali gönder
              Navigator.pop(context, true);
            }
          }
        } else {
          // Hata mesajı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('offers.acceptError'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Gönderilen teklif kartı oluştur
  Widget _buildSentOfferCard(Offer offer) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (offer.status) {
      case OfferStatus.accepted:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'offer.accepted'.tr();
        break;
      case OfferStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'offer.rejected'.tr();
        break;
      case OfferStatus.pending:
        if (offer.counterOfferAmount != null) {
          statusColor = Colors.orange;
          statusIcon = Icons.swap_horiz;
          statusText = 'offer.counterOffer'.tr();
        } else {
          statusColor = Colors.blue;
          statusIcon = Icons.schedule;
          statusText = 'offer.pending'.tr();
        }
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = offer.status.toString();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Araç bilgileri
            Row(
              children: [
                if (offer.vehicleImageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      offer.vehicleImageUrl,
                      width: 80,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.directions_car),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${offer.vehicleBrand} ${offer.vehicleModel}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${offer.vehicleYear}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Durum badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Fiyat bilgileri
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'offer.listingPrice'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCurrency(offer.listingPrice)} TL',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward, color: Colors.grey[400]),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'offer.yourOffer'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCurrency(offer.offerPrice)} TL',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Karşı teklif varsa göster
            if (offer.counterOfferAmount != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'offer.counterOfferAmount'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatCurrency(offer.counterOfferAmount!)} TL',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Karşı teklif için butonlar (pending durumunda)
                    if (offer.status == OfferStatus.pending) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _handleRejectCounterOffer(offer),
                              icon: const Icon(Icons.close, size: 18),
                              label: Text('offers.reject'.tr()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleAcceptCounterOffer(offer),
                              icon: const Icon(Icons.check, size: 18),
                              label: Text('offers.accept'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showCounterOfferDialog(offer),
                          icon: const Icon(Icons.local_offer, size: 18),
                          label: Text('offer.sendCounterOffer'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                            side: const BorderSide(color: Colors.deepPurple, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Satıcı cevabı varsa göster
            if (offer.sellerResponse != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.message, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        offer.sellerResponse!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tarih
            const SizedBox(height: 12),
            Text(
              _formatDate(offer.offerDate),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tüm bekleyen teklifleri reddet (YENİ)
  Future<void> _rejectAllOffers(List<Offer> offers) async {
    // Sadece bekleyen teklifleri filtrele
    final pendingOffers = offers.where((o) => o.isPending).toList();
    
    if (pendingOffers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reddedilecek bekleyen teklif yok.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Dikkat!'),
          ],
        ),
        content: Text(
          'Bu araca gelen ${pendingOffers.length} adet bekleyen teklifi reddetmek istediğinize emin misiniz?\n\n'
          'Reddedilen teklifler kalıcı olarak silinecektir.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tümünü Reddet'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Tüm teklifleri reddet
      int successCount = 0;
      
      for (var offer in pendingOffers) {
        bool success = await _offerService.rejectOffer(offer);
        if (success) successCount++;
      }

      if (mounted) {
        if (successCount == pendingOffers.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${successCount} teklif başarıyla reddedildi ve silindi.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${successCount}/${pendingOffers.length} teklif reddedildi.'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // Listeyi yenile
        await _loadOffers();
        
        // Eğer tüm bekleyen teklifler silindiyse, bir önceki ekrana dön ve güncelleme sinyali gönder
        if (successCount > 0 && widget.selectedVehicleId != null) {
          // Araç detay ekranındayız, araç listesine geri dönüp güncelleme yap
          Navigator.pop(context, true);
        }
      }
    }
  }

  Future<void> _handleRejectOffer(Offer offer) async {
    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teklifi Reddet'),
        content: Text('${offer.buyerName} ${_formatCurrency(offer.offerPrice)} TL ${'offers.rejectConfirmMessage'.tr()}\n\nReddedilen teklif kalıcı olarak silinecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reddet ve Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool success = await _offerService.rejectOffer(offer);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Teklif reddedildi ve silindi.'),
              backgroundColor: Colors.green,
            ),
          );

          // Listeyi yenile
          await _loadOffers();
          
          // Eğer bu araç detay ekranında isek ve artık bekleyen teklif kalmadıysa, geri dön
          if (widget.selectedVehicleId != null) {
            final remainingOffers = _incomingOffersByVehicle[widget.selectedVehicleId] ?? [];
            final hasPendingOffers = remainingOffers.any((o) => o.isPending);
            
            if (!hasPendingOffers) {
              // Artık bekleyen teklif yok, araç listesine dön ve güncelleme sinyali gönder
              Navigator.pop(context, true);
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('offers.acceptError'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Karşı teklifi kabul et
  Future<void> _handleAcceptCounterOffer(Offer offer) async {
    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Karşı Teklifi Kabul Et'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${offer.vehicleBrand} ${offer.vehicleModel} için karşı teklifi kabul etmek istediğinize emin misiniz?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Teklifiniz:', style: TextStyle(color: Colors.grey[600])),
                      Text(
                        '${_formatCurrency(offer.offerPrice)} TL',
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
                      const Text(
                        'Karşı Teklif:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_formatCurrency(offer.counterOfferAmount!)} TL',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• Araç garajınıza eklenecek',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            Text(
              '• Bakiyenizden ${_formatCurrency(offer.counterOfferAmount!)} TL düşecek',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kabul Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Kullanıcı bilgilerini al
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) return;

      // Bakiye kontrolü
      if (currentUser.balance < offer.counterOfferAmount!) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('purchase.insufficientBalance'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Teklifi kabul et ve satın alma işlemini gerçekleştir
      bool success = await _acceptCounterOffer(offer, currentUser);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Karşı teklif kabul edildi! Araç garajınıza eklendi.'),
              backgroundColor: Colors.green,
            ),
          );

          // Listeyi yenile
          await _loadOffers();
          
          // Eğer bu araç detay ekranında isek ve artık bekleyen teklif kalmadıysa, geri dön
          if (widget.selectedVehicleId != null) {
            final remainingOffers = _incomingOffersByVehicle[widget.selectedVehicleId] ?? [];
            final hasPendingOffers = remainingOffers.any((o) => o.isPending);
            
            if (!hasPendingOffers) {
              // Artık bekleyen teklif yok, araç listesine dön ve güncelleme sinyali gönder
              Navigator.pop(context, true);
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('offers.acceptError'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Karşı teklifi reddet
  Future<void> _handleRejectCounterOffer(Offer offer) async {
    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Karşı Teklifi Reddet'),
        content: Text(
          '${offer.vehicleBrand} ${offer.vehicleModel} için gelen karşı teklifi reddetmek istediğinize emin misiniz?\n\n'
          'Reddedilen teklif kalıcı olarak silinecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reddet ve Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool success = await _offerService.rejectOffer(offer);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Karşı teklif reddedildi ve silindi.'),
              backgroundColor: Colors.green,
            ),
          );

          // Listeyi yenile
          await _loadOffers();
          
          // Eğer bu araç detay ekranında isek ve artık bekleyen teklif kalmadıysa, geri dön
          if (widget.selectedVehicleId != null) {
            final remainingOffers = _incomingOffersByVehicle[widget.selectedVehicleId] ?? [];
            final hasPendingOffers = remainingOffers.any((o) => o.isPending);
            
            if (!hasPendingOffers) {
              // Artık bekleyen teklif yok, araç listesine dön ve güncelleme sinyali gönder
              Navigator.pop(context, true);
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('offers.rejectError'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Karşı teklif gönderme dialogunu göster
  void _showCounterOfferDialog(Offer offer) {
    final TextEditingController counterOfferController = TextEditingController();
    final minOffer = offer.offerPrice;
    final maxOffer = offer.counterOfferAmount!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('offer.sendCounterOffer'.tr()),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${offer.vehicleBrand} ${offer.vehicleModel}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'offer.yourOffer'.tr(),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        Text(
                          '${_formatCurrency(minOffer)} TL',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'offer.sellerCounterOffer'.tr(),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        Text(
                          '${_formatCurrency(maxOffer)} TL',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: counterOfferController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'offer.yourCounterOffer'.tr(),
                  hintText: '${_formatCurrency(minOffer)} - ${_formatCurrency(maxOffer)} TL',
                  suffixText: 'TL',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.money),
                  helperText: 'offer.counterOfferRange'.tr(),
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'offer.counterOfferInfo'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
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
              final offerText = counterOfferController.text.trim();
              if (offerText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('offer.enterAmountError'.tr())),
                );
                return;
              }

              final newOffer = double.tryParse(offerText.replaceAll('.', ''));
              if (newOffer == null || newOffer <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('offer.invalidAmountError'.tr())),
                );
                return;
              }

              // Aralık kontrolü
              if (newOffer <= minOffer || newOffer >= maxOffer) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('offer.counterOfferRangeError'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _submitCounterOffer(offer, newOffer);
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

  /// Karşı teklif gönder
  Future<void> _submitCounterOffer(Offer originalOffer, double newOfferAmount) async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final result = await _offerService.submitCounterOfferResponse(
        offer: originalOffer,
        newOfferAmount: newOfferAmount,
      );

      // Loading kapat
      if (mounted) Navigator.pop(context);

      if (!result['success']) {
        throw Exception(result['error'] ?? 'Unknown error');
      }

      // Sonuç dialogunu göster
      if (mounted) {
        _showCounterOfferResultDialog(result, originalOffer);
      }

      // Listeyi yenile
      _loadOffers();
    } catch (e) {
      // Loading kapat
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('offer.sendError'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Karşı teklif sonuç dialogunu göster
  void _showCounterOfferResultDialog(Map<String, dynamic> result, Offer originalOffer) {
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
      iconColor = Colors.orange;
      title = 'offer.counterOffer'.tr();
    }

    showDialog(
      context: context,
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
            if (newCounterOffer != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('offer.newCounterOffer'.tr()),
                    Text(
                      '${_formatCurrency(newCounterOffer)} TL',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.deepOrange,
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      decision == 'accept' 
                          ? 'offer.purchaseCompleted'.tr()
                          : 'offer.negotiationContinues'.tr(),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }

  /// Gelen teklife karşı teklif gönderme dialogunu göster
  void _showCounterOfferDialogForIncoming(Offer offer) {
    final TextEditingController counterOfferController = TextEditingController();
    final minOffer = offer.offerPrice; // Alıcının teklifi
    final maxOffer = offer.listingPrice; // İlan fiyatı

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('offers.counterOfferDialogTitle'.tr()),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'offers.counterOfferDialogDesc'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${offer.vehicleBrand} ${offer.vehicleModel}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'offers.buyerOffer'.tr(),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        Text(
                          '${_formatCurrency(minOffer)} ₺',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'vehicles.listingPrice'.tr(),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        Text(
                          '${_formatCurrency(maxOffer)} ₺',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: counterOfferController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'offers.yourCounterOffer'.tr(),
                  hintText: '${_formatCurrency(minOffer)} - ${_formatCurrency(maxOffer)} ₺',
                  suffixText: 'TL',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.money),
                  helperText: 'Alıcının teklifi ile ilan fiyatı arasında bir değer girin',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'offers.counterOfferInfo'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
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
              final offerText = counterOfferController.text.trim();
              if (offerText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('offer.enterAmountError'.tr())),
                );
                return;
              }

              final newOffer = double.tryParse(offerText.replaceAll('.', ''));
              if (newOffer == null || newOffer <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('offer.invalidAmountError'.tr())),
                );
                return;
              }

              // Aralık kontrolü
              if (newOffer <= minOffer || newOffer >= maxOffer) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('offers.counterOfferRangeError'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _submitCounterOfferForIncoming(offer, newOffer);
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

  /// Gelen teklife karşı teklif gönder
  Future<void> _submitCounterOfferForIncoming(Offer originalOffer, double counterOfferAmount) async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await _offerService.sendCounterOfferToIncomingOffer(
        originalOffer: originalOffer,
        counterOfferAmount: counterOfferAmount,
      );

      // Loading kapat
      if (mounted) Navigator.pop(context);

      if (!result['success']) {
        throw Exception(result['error'] ?? 'Unknown error');
      }

      // Sonuç dialogunu göster
      if (mounted) {
        _showCounterOfferResultDialogForIncoming(result, originalOffer);
      }

      // Listeyi yenile
      _loadOffers();
    } catch (e) {
      // Loading kapat
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('offers.counterOfferError'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Gelen teklife karşı teklif sonuç dialogunu göster
  void _showCounterOfferResultDialogForIncoming(Map<String, dynamic> result, Offer originalOffer) {
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
      iconColor = Colors.orange;
      title = 'offer.counterOffer'.tr();
    }

    showDialog(
      context: context,
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
              'offers.buyerResponse'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              response,
              style: const TextStyle(fontSize: 16),
            ),
            if (newCounterOffer != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('offer.newCounterOffer'.tr()),
                    Text(
                      '${_formatCurrency(newCounterOffer)} TL',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.deepOrange,
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      decision == 'accept' 
                          ? 'offers.acceptSuccess'.tr()
                          : decision == 'reject'
                              ? 'Alıcı teklifinizi reddetti. Başka bir teklif bekleyebilirsiniz.'
                              : 'Pazarlık devam ediyor. Alıcının yeni teklifini yukarıda görebilirsiniz.',
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }

  /// Karşı teklifi kabul et ve satın alma işlemini yap
  Future<bool> _acceptCounterOffer(Offer offer, User user) async {
    try {
      // 1. Bakiyeyi düş
      final newBalance = user.balance - offer.counterOfferAmount!;
      bool balanceUpdated = await _db.updateUser(user.id, {'balance': newBalance});
      if (!balanceUpdated) return false;

      // 2. Teklifi kabul edildi olarak işaretle
      bool offerUpdated = await _db.updateOfferStatus(offer.offerId, OfferStatus.accepted);
      if (!offerUpdated) {
        // Rollback
        await _db.updateUser(user.id, {'balance': user.balance});
        return false;
      }

      // 3. Aracı kullanıcıya ekle
      final userVehicle = UserVehicle.purchase(
        userId: user.id,
        vehicleId: offer.vehicleId,
        brand: offer.vehicleBrand,
        model: offer.vehicleModel,
        year: offer.vehicleYear,
        mileage: 50000, // Varsayılan
        purchasePrice: offer.counterOfferAmount!,
        color: 'Bilinmiyor',
        fuelType: 'Benzin',
        transmission: 'Manuel',
        engineSize: '1.6',
        driveType: 'Önden',
        hasWarranty: false,
        hasAccidentRecord: false,
        score: 75,
        imageUrl: offer.vehicleImageUrl,
      );

      bool vehicleAdded = await _db.addUserVehicle(userVehicle);
      if (!vehicleAdded) {
        // Rollback
        await _db.updateUser(user.id, {'balance': user.balance});
        await _db.updateOfferStatus(offer.offerId, OfferStatus.pending);
        return false;
      }

      return true;
    } catch (e) {
      
      return false;
    }
  }
}

