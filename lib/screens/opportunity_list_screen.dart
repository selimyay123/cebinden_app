import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/market_refresh_service.dart';
import '../services/localization_service.dart';
import '../widgets/modern_alert_dialog.dart';
import '../services/database_helper.dart';
import '../models/vehicle_model.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import '../services/auth_service.dart';
import 'vehicle_detail_screen.dart';
import 'package:intl/intl.dart';

class OpportunityListScreen extends StatefulWidget {
  const OpportunityListScreen({super.key});

  @override
  State<OpportunityListScreen> createState() => _OpportunityListScreenState();
}

class _OpportunityListScreenState extends State<OpportunityListScreen> {
  final MarketRefreshService _marketService = MarketRefreshService();
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();
  
  List<OpportunityListing> _listings = [];
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _currentUser = await _authService.getCurrentUser();
    _listings = _marketService.getOpportunityListings();
    
    setState(() => _isLoading = false);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 0);
    return formatter.format(amount).trim();
  }

  String _formatNumber(int number) {
    final formatter = NumberFormat.decimalPattern('tr_TR');
    return formatter.format(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('opportunity.title'.tr()),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/general_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _listings.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _listings.length,
                      itemBuilder: (context, index) {
                        return _buildOpportunityCard(_listings[index]);
                      },
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
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'opportunity.emptyTitle'.tr(),
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'opportunity.emptySubtitle'.tr(),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(OpportunityListing listing) {
    final vehicle = listing.vehicle;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5), // Fırsat vurgusu
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(listing),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Üst Kısım: Resim ve Bilgiler
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Araç Resmi
                  Container(
                    width: 100,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: vehicle.imageUrl != null
                          ? DecorationImage(
                              image: AssetImage(vehicle.imageUrl!),
                              fit: BoxFit.contain,
                            )
                          : null,
                    ),
                    child: vehicle.imageUrl == null
                        ? const Icon(Icons.directions_car, size: 40, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  
                  // Bilgiler
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                vehicle.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Fırsat Etiketi
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'opportunity.tag'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${vehicle.year} • ${_formatNumber(vehicle.mileage)} km',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          listing.reason,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Alt Kısım: Fiyat ve Satın Al
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'vehicles.price'.tr(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        '${_formatCurrency(listing.originalPrice)} TL',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        '${_formatCurrency(vehicle.price)} TL',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => _navigateToDetail(listing),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('opportunity.inspect'.tr()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(OpportunityListing listing) async {
    // Detay sayfasına git
    // Not: Normal VehicleDetailScreen kullanılabilir, ancak satın alma işlemi orada
    // MarketRefreshService.removeListing çağırıyor.
    // Fırsat araçları için removeOpportunityListing çağrılmalı.
    // Bu yüzden VehicleDetailScreen'e bir parametre eklemek veya
    // Satın alma işlemini burada yapmak daha mantıklı olabilir.
    // Ancak VehicleDetailScreen çok detaylı, onu kullanmak daha iyi.
    // VehicleDetailScreen'i güncellememiz gerekebilir.
    
    // Şimdilik direkt satın alma dialogu açalım bu ekranda
    _showPurchaseDialog(listing);
  }

  void _showPurchaseDialog(OpportunityListing listing) {
    final vehicle = listing.vehicle;
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: '${'purchase.title'.tr()}: ${vehicle.fullName}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('opportunity.buyConfirmation'.tr()),
            const SizedBox(height: 16),
            Text(
              '${'vehicles.price'.tr()}: ${_formatCurrency(vehicle.price)} TL',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
             Text(
              'Normal Fiyat: ${_formatCurrency(listing.originalPrice)} TL',
              style: TextStyle(
                color: Colors.grey[500],
                decoration: TextDecoration.lineThrough,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${'purchase.currentBalance'.tr()}: ${_formatCurrency(_currentUser?.balance ?? 0)} TL',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        buttonText: 'purchase.title'.tr(),
        onPressed: () => _processPurchase(vehicle),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
        icon: Icons.shopping_cart,
        iconColor: Colors.deepPurple,
      ),
    );
  }

  Future<void> _processPurchase(Vehicle vehicle) async {
    if (_currentUser == null) return;
    
    // Close dialog immediately to prevent stuck state
    Navigator.of(context, rootNavigator: true).pop();

    // Bakiye kontrolü
    if (_currentUser!.balance < vehicle.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('purchase.insufficientBalance'.tr())),
      );
      return;
    }

    // Garaj limiti kontrolü
    final activeVehicles = await _db.getUserActiveVehicles(_currentUser!.id);
    if (activeVehicles.length >= _currentUser!.garageLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errors.garageFull'.tr())),
      );
      return;
    }

    // Satın alma işlemi
    try {
      // 1. Bakiyeyi düş
      final newBalance = _currentUser!.balance - vehicle.price;
      await _db.updateUser(_currentUser!.id, {
        'balance': newBalance,
        'totalVehiclesBought': _currentUser!.totalVehiclesBought + 1,
      });

      // 2. Aracı kullanıcıya ekle
      // UserVehicle oluştur
      final userVehicle = UserVehicle.fromVehicle(
        vehicle, 
        _currentUser!.id, 
        purchasePrice: vehicle.price,
      );
      await _db.addUserVehicle(userVehicle);

      // 3. Listeden kaldır
      _marketService.removeOpportunityListing(vehicle.id);

      // 4. Başarı mesajı ve yenileme
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('purchase.purchaseSuccess'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Listeyi yenile
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    }
  }
}
