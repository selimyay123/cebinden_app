import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';
import 'create_listing_screen.dart';

class MyVehiclesScreen extends StatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  
  User? _currentUser;
  List<UserVehicle> _myVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyVehicles();
  }

  Future<void> _loadMyVehicles() async {
    setState(() => _isLoading = true);
    
    final user = await _authService.getCurrentUser();
    if (user != null) {
      final vehicles = await _db.getUserActiveVehicles(user.id);
      setState(() {
        _currentUser = user;
        _myVehicles = vehicles;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text('home.myVehicles'.tr()),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myVehicles.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadMyVehicles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _myVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = _myVehicles[index];
                      return _buildVehicleCard(vehicle);
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 120,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'vehicles.noVehicles'.tr(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'myVehicles.buildCollection'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.shopping_cart),
              label: Text('misc.buyVehicleButton'.tr()),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(UserVehicle vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve Araç Bilgileri
            Row(
              children: [
                // Araç İkonu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    size: 40,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Araç Detayları
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${vehicle.year}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.speed, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatNumber(vehicle.mileage)} km',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Satışta Badge'i (eğer satışta ise)
                          if (vehicle.isListedForSale) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.store,
                                    size: 12,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'vehicles.onSale'.tr(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              vehicle.fuelType,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                              vehicle.transmission,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // Satın Alma Bilgileri
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'vehicles.purchaseDate'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(vehicle.purchaseDate),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'vehicles.daysOwned'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${vehicle.daysOwned} ${'misc.days'.tr()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Aksiyon Butonları
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showVehicleDetailsDialog(vehicle);
                    },
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: Text('misc.vehicleDetails'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Eğer araç zaten satışta ise uyarı ver
                      if (vehicle.isListedForSale) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('myVehicles.alreadyListed'.tr()),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      
                      // Satışa çıkarma ekranına git
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateListingScreen(vehicle: vehicle),
                        ),
                      );
                      
                      // Eğer satışa çıkarma başarılıysa listeyi yenile
                      if (result == true) {
                        await _loadMyVehicles();
                      }
                    },
                    icon: const Icon(Icons.sell, size: 18),
                    label: Text('misc.sellVehicle'.tr()),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
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

  void _showVehicleDetailsDialog(UserVehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.deepPurple.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${vehicle.year} • ${_formatNumber(vehicle.mileage)} km',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Satın Alma Bilgileri
                      _buildSectionTitle('vehicles.purchaseDate'.tr()),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildDetailRow(
                          Icons.shopping_cart,
                          'vehicles.purchasePrice'.tr(),
                          '${_formatCurrency(vehicle.purchasePrice)} TL',
                          Colors.deepPurple,
                        ),
                        _buildDetailRow(
                          Icons.calendar_today,
                          'vehicles.purchaseDate'.tr(),
                          _formatDate(vehicle.purchaseDate),
                          Colors.blue,
                        ),
                        _buildDetailRow(
                          Icons.access_time,
                          'vehicles.daysOwned'.tr(),
                          '${vehicle.daysOwned} ${'misc.days'.tr()}',
                          Colors.green,
                        ),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      // Teknik Özellikler
                      _buildSectionTitle('vehicles.technicalSpecs'.tr()),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildDetailRow(
                          Icons.color_lens,
                          'vehicles.color'.tr(),
                          vehicle.color,
                          Colors.pink,
                        ),
                        _buildDetailRow(
                          Icons.local_gas_station,
                          'vehicles.fuelType'.tr(),
                          vehicle.fuelType,
                          Colors.orange,
                        ),
                        _buildDetailRow(
                          Icons.settings,
                          'vehicles.transmission'.tr(),
                          vehicle.transmission,
                          Colors.teal,
                        ),
                        _buildDetailRow(
                          Icons.speed,
                          'vehicles.engineSize'.tr(),
                          vehicle.engineSize,
                          Colors.red,
                        ),
                        _buildDetailRow(
                          Icons.compare_arrows,
                          'vehicles.driveType'.tr(),
                          vehicle.driveType,
                          Colors.indigo,
                        ),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      // Durum & Garanti
                      _buildSectionTitle('vehicles.statusWarranty'.tr()),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildDetailRow(
                          Icons.verified_user,
                          'vehicles.warrantyStatus'.tr(),
                          vehicle.hasWarranty ? 'vehicles.yes'.tr() : 'vehicles.no'.tr(),
                          vehicle.hasWarranty ? Colors.green : Colors.grey,
                        ),
                        _buildDetailRow(
                          Icons.car_crash,
                          'vehicles.accidentRecord'.tr(),
                          vehicle.hasAccidentRecord ? 'vehicles.yes'.tr() : 'vehicles.no'.tr(),
                          vehicle.hasAccidentRecord ? Colors.red : Colors.green,
                        ),
                        _buildDetailRow(
                          Icons.star,
                          'İlan Skoru',
                          '${vehicle.score}/100',
                          Colors.amber,
                        ),
                      ]),
                      
                      // Satış Durumu (eğer satışta ise)
                      if (vehicle.isListedForSale) ...[
                        const SizedBox(height: 20),
                        _buildSectionTitle('vehicles.listingInfo'.tr()),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildDetailRow(
                            Icons.local_offer,
                            'vehicles.listingPrice'.tr(),
                            '${_formatCurrency(vehicle.listingPrice ?? 0)} TL',
                            Colors.green,
                          ),
                          if (vehicle.listedDate != null)
                            _buildDetailRow(
                              Icons.calendar_today,
                              'vehicles.listingDate'.tr(),
                              _formatDate(vehicle.listedDate!),
                              Colors.blue,
                            ),
                          _buildDetailRow(
                            Icons.trending_up,
                            'Potansiyel Kar/Zarar',
                            '${_formatCurrency((vehicle.listingPrice ?? 0) - vehicle.purchasePrice)} TL',
                            (vehicle.listingPrice ?? 0) >= vehicle.purchasePrice
                                ? Colors.green
                                : Colors.red,
                          ),
                        ]),
                        if (vehicle.listingDescription != null &&
                            vehicle.listingDescription!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.description, 
                                      size: 16, 
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'vehicles.description'.tr(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  vehicle.listingDescription!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
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
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

