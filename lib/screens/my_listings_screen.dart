import 'package:flutter/material.dart';
import '../models/user_vehicle_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();
  List<UserVehicle> _userListedVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserListedVehicles();
  }

  Future<void> _loadUserListedVehicles() async {
    setState(() {
      _isLoading = true;
    });
    final currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      final listedVehicles = await _db.getUserListedVehicles(currentUser.id);
      setState(() {
        _userListedVehicles = listedVehicles;
        _isLoading = false;
      });
    } else {
      setState(() {
        _userListedVehicles = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('listings.title'.tr()),
            elevation: 0,
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserListedVehicles,
              child: _userListedVehicles.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _userListedVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _userListedVehicles[index];
                        return _buildListingCard(vehicle);
                      },
                    ),
            ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'listings.noListings'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'listings.noListingsDesc'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(UserVehicle vehicle) {
    final daysListed = vehicle.listedDate != null
        ? DateTime.now().difference(vehicle.listedDate!).inDays
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Araç ikonu/resmi
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vehicle.year} • ${_formatNumber(vehicle.mileage)} km',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'vehicles.onSale'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Fiyat Bilgileri
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'vehicles.listingPrice'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatCurrency(vehicle.listingPrice ?? 0)} TL',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'vehicles.purchasePrice'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCurrency(vehicle.purchasePrice)} TL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Kar/Zarar Göstergesi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getProfitColor(vehicle).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getProfitIcon(vehicle),
                    color: _getProfitColor(vehicle),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${'myListings.potential'.tr()} ${_isProfit(vehicle) ? 'myListings.profit'.tr() : 'myListings.loss'.tr()}: ${_formatCurrency(_getPotentialProfit(vehicle))} TL',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getProfitColor(vehicle),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // İlan Açıklaması
            if (vehicle.listingDescription != null) ...[
              Text(
                'myListings.description'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                vehicle.listingDescription!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
            ],
            
            // İlan İstatistikleri
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  Icons.calendar_today,
                  '${'myListings.listed'.tr()}: ${_formatDate(vehicle.listedDate ?? DateTime.now())}',
                ),
                _buildInfoChip(
                  Icons.access_time,
                  '$daysListed ${'misc.daysAgo'.tr()}',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Butonlar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: İlanı düzenle
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('sell.editListingComingSoon'.tr()),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: Text('sell.editButton'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: İlanı kaldır
                      _showRemoveListingDialog(vehicle);
                    },
                    icon: const Icon(Icons.close),
                    label: Text('sell.removeListing'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  bool _isProfit(UserVehicle vehicle) {
    return (vehicle.listingPrice ?? 0) >= vehicle.purchasePrice;
  }

  double _getPotentialProfit(UserVehicle vehicle) {
    return ((vehicle.listingPrice ?? 0) - vehicle.purchasePrice).abs();
  }

  Color _getProfitColor(UserVehicle vehicle) {
    return _isProfit(vehicle) ? Colors.green : Colors.red;
  }

  IconData _getProfitIcon(UserVehicle vehicle) {
    return _isProfit(vehicle) ? Icons.trending_up : Icons.trending_down;
  }

  void _showRemoveListingDialog(UserVehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('sell.removeListing'.tr()),
        content: Text(
          '${vehicle.fullName} ${'myListings.removeConfirm'.tr()}\n\n${'myListings.willStayInGarage'.tr()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // İlanı kaldır
              final success = await _db.updateUserVehicle(vehicle.id, {
                'isListedForSale': false,
                'listingPrice': null,
                'listingDescription': null,
                'listedDate': null,
              });
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('sell.listingRemoved'.tr()),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadUserListedVehicles(); // Listeyi yenile
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('common.delete'.tr()),
          ),
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

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

