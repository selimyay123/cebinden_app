import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_vehicle_model.dart';
import '../models/vehicle_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/favorite_service.dart';
import '../services/localization_service.dart';
import '../utils/brand_colors.dart';
import 'vehicle_detail_screen.dart';
import 'package:intl/intl.dart';

class MyListingsScreen extends StatefulWidget {
  final String? selectedBrand; // null = marka listesi göster, brand = o markanın ilanlarını göster
  final int initialTab; // 0 = İlanlarım, 1 = Favori İlanlarım

  const MyListingsScreen({
    super.key,
    this.selectedBrand,
    this.initialTab = 0,
  });

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();
  final FavoriteService _favoriteService = FavoriteService();
  List<UserVehicle> _userListedVehicles = [];
  List<Vehicle> _favoriteListings = [];
  bool _isLoading = true;
  late TabController _tabController;
  
  // Marka bazında gruplandırılmış ilanlar
  Map<String, List<UserVehicle>> _listingsByBrand = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadUserListedVehicles();
    _loadFavoriteListings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserListedVehicles() async {
    setState(() {
      _isLoading = true;
    });
    final currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      final listedVehicles = await _db.getUserListedVehicles(currentUser.id);
      
      // İlanları markaya göre gruplandır
      final Map<String, List<UserVehicle>> grouped = {};
      for (var vehicle in listedVehicles) {
        if (!grouped.containsKey(vehicle.brand)) {
          grouped[vehicle.brand] = [];
        }
        grouped[vehicle.brand]!.add(vehicle);
      }
      
      setState(() {
        _userListedVehicles = listedVehicles;
        _listingsByBrand = grouped;
        _isLoading = false;
      });
    } else {
      setState(() {
        _userListedVehicles = [];
        _listingsByBrand = {};
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFavoriteListings() async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      final favorites = await _favoriteService.getUserFavorites(currentUser.id);
      setState(() {
        _favoriteListings = favorites;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        // Eğer belirli bir marka seçilmişse, eski davranışı koru
        if (widget.selectedBrand != null) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              title: Text(widget.selectedBrand!),
              elevation: 0,
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildListingList(),
          );
        }
        
        // Yeni TabBar'lı görünüm
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text('listings.title'.tr()),
            elevation: 0,
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'listings.myListings'.tr()),
                Tab(text: 'favorites.myFavorites'.tr()),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: İlanlarım
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _userListedVehicles.isEmpty
                      ? _buildEmptyState()
                      : _buildBrandList(),
              
              // Tab 2: Favori İlanlarım
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _favoriteListings.isEmpty
                      ? _buildEmptyFavoritesState()
                      : _buildFavoritesList(),
            ],
          ),
        );
      },
    );
  }
  
  // Marka listesi (1. seviye)
  Widget _buildBrandList() {
    return RefreshIndicator(
      onRefresh: _loadUserListedVehicles,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: _listingsByBrand.length,
        itemBuilder: (context, index) {
          final brand = _listingsByBrand.keys.elementAt(index);
          final listings = _listingsByBrand[brand]!;
          return _buildBrandCard(brand, listings.length);
        },
      ),
    );
  }
  
  // Belirli bir markanın ilan listesi (2. seviye)
  Widget _buildListingList() {
    final brandListings = _listingsByBrand[widget.selectedBrand] ?? [];
    
    return RefreshIndicator(
      onRefresh: _loadUserListedVehicles,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: brandListings.length,
        itemBuilder: (context, index) {
          final vehicle = brandListings[index];
          return _buildListingCard(vehicle);
        },
      ),
    );
  }

  // Marka kartı widget'ı
  Widget _buildBrandCard(String brand, int listingCount) {
    final brandColor = BrandColors.getColor(brand, defaultColor: Colors.deepPurple);
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyListingsScreen(selectedBrand: brand),
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
                Icons.store,
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
                  // Badge (İlan Sayısı)
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
                        '$listingCount',
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
                        listingCount == 1 
                          ? '1 ilan' 
                          : '$listingCount ilan',
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

  Widget _buildEmptyFavoritesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'favorites.noFavorites'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'favorites.noFavoritesDesc'.tr(),
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

  Widget _buildFavoritesList() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadFavoriteListings();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favoriteListings.length,
        itemBuilder: (context, index) {
          final vehicle = _favoriteListings[index];
          return _buildFavoriteVehicleCard(vehicle);
        },
      ),
    );
  }

  Widget _buildFavoriteVehicleCard(Vehicle vehicle) {
    final brandColor = BrandColors.getColor(vehicle.brand, defaultColor: Colors.deepPurple);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          // Araç detay sayfasına git
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VehicleDetailScreen(vehicle: vehicle),
            ),
          );
          // Geri dönünce favorileri yenile (ilan satılmış olabilir)
          await _loadFavoriteListings();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Araç ikonu
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: brandColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: brandColor,
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
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              vehicle.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Favori ikonu
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () async {
                      final currentUser = await _authService.getCurrentUser();
                      if (currentUser != null) {
                        await _favoriteService.removeFavorite(currentUser.id, vehicle.id);
                        await _loadFavoriteListings();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('favorites.removedFromFavorites'.tr()),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    },
                    tooltip: 'favorites.removeFromFavorites'.tr(),
                  ),
                ],
              ),
              const Divider(height: 24),
              
              // Fiyat ve Teknik Bilgiler
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'vehicles.price'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatCurrency(vehicle.price)} TL',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildInfoChip(Icons.local_gas_station, vehicle.fuelType),
                      const SizedBox(height: 6),
                      _buildInfoChip(Icons.settings, vehicle.transmission),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
                      _showEditListingDialog(vehicle);
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

  void _showEditListingDialog(UserVehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => _EditListingDialog(
        vehicle: vehicle,
        onSave: (double price, String description) async {
          // İlanı güncelle
          final success = await _db.updateUserVehicle(vehicle.id, {
            'listingPrice': price,
            'listingDescription': description,
          });
          
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('sell.listingUpdated'.tr()),
                backgroundColor: Colors.green,
              ),
            );
            _loadUserListedVehicles(); // Listeyi yenile
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('sell.listingUpdateFailed'.tr()),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
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


class _EditListingDialog extends StatefulWidget {
  final UserVehicle vehicle;
  final Function(double price, String description) onSave;

  const _EditListingDialog({
    required this.vehicle,
    required this.onSave,
  });

  @override
  State<_EditListingDialog> createState() => _EditListingDialogState();
}

class _EditListingDialogState extends State<_EditListingDialog> {
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: _formatCurrency((widget.vehicle.listingPrice ?? 0)).replaceAll('.', ''),
    );
    _descriptionController = TextEditingController(
      text: widget.vehicle.listingDescription ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Dinamik Kar/Zarar Hesabı
    double currentPrice = 0;
    try {
      currentPrice = double.parse(_priceController.text.replaceAll('.', ''));
    } catch (e) {
      currentPrice = 0;
    }
    
    final profit = currentPrice - widget.vehicle.purchasePrice;
    final isProfit = profit >= 0;
    final profitPercent = widget.vehicle.purchasePrice > 0 
        ? (profit / widget.vehicle.purchasePrice) * 100 
        : 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(
            child: Text('sell.editListing'.tr()),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Araç Bilgisi
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vehicle.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.vehicle.year} • ${_formatNumber(widget.vehicle.mileage)} km',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Alış Fiyatı Gösterimi
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${'vehicles.purchasePrice'.tr()}: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${_formatCurrency(widget.vehicle.purchasePrice)} TL',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Fiyat Girişi
              Text(
                'vehicles.listingPrice'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ThousandsSeparatorInputFormatter(),
                ],
                onChanged: (value) {
                  setState(() {}); // UI'ı güncelle
                },
                decoration: InputDecoration(
                  prefixText: '₺ ',
                  suffixText: 'TL',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'vehicles.priceRequired'.tr();
                  }
                  final price = double.tryParse(value.replaceAll('.', ''));
                  if (price == null || price <= 0) {
                    return 'vehicles.validPrice'.tr();
                  }
                  return null;
                },
              ),
              
              // Dinamik Kar/Zarar Göstergesi
              if (_priceController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isProfit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isProfit ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isProfit ? Icons.trending_up : Icons.trending_down,
                        color: isProfit ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${isProfit ? 'Kar' : 'Zarar'}: ${_formatCurrency(profit.abs())} TL (%${profitPercent.abs().toStringAsFixed(1)})',
                          style: TextStyle(
                            color: isProfit ? Colors.green[700] : Colors.red[700],
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
              
              // Açıklama Girişi
              Text(
                'myListings.description'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  hintText: 'vehicles.descriptionHint'.tr(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              
              final newPrice = double.parse(_priceController.text.replaceAll('.', ''));
              final newDescription = _descriptionController.text.trim();
              
              widget.onSave(newPrice, newDescription);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: Text('common.save'.tr()),
        ),
      ],
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

