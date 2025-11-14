import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/offer_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/offer_service.dart';
import '../services/localization_service.dart';

class MyOffersScreen extends StatefulWidget {
  const MyOffersScreen({Key? key}) : super(key: key);

  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();
  final OfferService _offerService = OfferService();

  List<Offer> _allOffers = [];
  Map<String, List<Offer>> _offersByVehicle = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Tüm teklifleri getir
      _allOffers = await _db.getOffersBySellerId(currentUser.id);

      // Araca göre grupla
      _offersByVehicle = {};
      for (var offer in _allOffers) {
        if (!_offersByVehicle.containsKey(offer.vehicleId)) {
          _offersByVehicle[offer.vehicleId] = [];
        }
        _offersByVehicle[offer.vehicleId]!.add(offer);
      }
    } catch (e) {
      print('❌ Error loading offers: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('offers.title'.tr()),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allOffers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadOffers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _offersByVehicle.length,
                    itemBuilder: (context, index) {
                      final vehicleId = _offersByVehicle.keys.elementAt(index);
                      final offers = _offersByVehicle[vehicleId]!;
                      return _buildVehicleCard(vehicleId, offers);
                    },
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
            Icons.inbox_outlined,
            size: 120,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'offers.noOffers'.tr(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'offers.noOffersDesc'.tr(),
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

  Widget _buildVehicleCard(String vehicleId, List<Offer> offers) {
    // İlk teklifi referans al (araç bilgileri aynı)
    final firstOffer = offers.first;
    
    // Bekleyen teklifler
    final pendingOffers = offers.where((o) => o.isPending).toList();
    final acceptedOffers = offers.where((o) => o.status == OfferStatus.accepted).toList();
    final rejectedOffers = offers.where((o) => o.status == OfferStatus.rejected).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    width: 80,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.directions_car, color: Colors.grey),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Araç Bilgisi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${firstOffer.vehicleBrand} ${firstOffer.vehicleModel}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${firstOffer.vehicleYear} Model',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'İlan Fiyatı: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${_formatCurrency(firstOffer.listingPrice)} TL',
                            style: const TextStyle(
                              fontSize: 14,
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
            ),
          ),

          // Teklif İstatistikleri
          if (offers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip('Bekleyen', pendingOffers.length, Colors.orange),
                  _buildStatChip('Kabul', acceptedOffers.length, Colors.green),
                  _buildStatChip('Red', rejectedOffers.length, Colors.red),
                ],
              ),
            ),

          // Bekleyen Teklifler
          if (pendingOffers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bekleyen Teklifler',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...pendingOffers.map((offer) => _buildOfferTile(offer)),
                ],
              ),
            ),

          // Kabul Edilen/Reddedilen Teklifler (Daraltılmış)
          if (acceptedOffers.isNotEmpty || rejectedOffers.isNotEmpty)
            ExpansionTile(
              title: Text('offers.history'.tr()),
              children: [
                ...acceptedOffers.map((offer) => _buildOfferTile(offer, compact: true)),
                ...rejectedOffers.map((offer) => _buildOfferTile(offer, compact: true)),
              ],
            ),
        ],
      ),
    );
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
                    '${_formatCurrency(offer.offerPrice)} TL',
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleAcceptOffer(offer),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text('Kabul Et'),
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
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleRejectOffer(offer),
                    icon: const Icon(Icons.cancel, size: 20),
                    label: const Text('Reddet'),
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
                        '${_formatCurrency(offer.offerPrice)} TL',
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
                  Text('• Bakiyenize ${_formatCurrency(offer.offerPrice)} TL eklenecek'),
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
          _loadOffers();
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

  Future<void> _handleRejectOffer(Offer offer) async {
    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teklifi Reddet'),
        content: Text('${offer.buyerName} ${_formatCurrency(offer.offerPrice)} TL ${'offers.rejectConfirmMessage'.tr()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reddet'),
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
              content: Text('Teklif reddedildi.'),
              backgroundColor: Colors.orange,
            ),
          );

          // Listeyi yenile
          _loadOffers();
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
}

