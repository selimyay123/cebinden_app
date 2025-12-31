import 'package:flutter/material.dart';
import '../models/user_vehicle_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';
import 'create_listing_screen.dart';
import 'home_screen.dart';
import '../utils/vehicle_utils.dart';

class SellVehicleScreen extends StatefulWidget {
  const SellVehicleScreen({super.key});

  @override
  State<SellVehicleScreen> createState() => _SellVehicleScreenState();
}

class _SellVehicleScreenState extends State<SellVehicleScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();
  List<UserVehicle> _userVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserVehicles();
  }

  Future<void> _loadUserVehicles() async {
    setState(() {
      _isLoading = true;
    });
    final currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      // Sadece satılmamış ve satışa çıkarılmamış araçları getir
      final allVehicles = await _db.getUserActiveVehicles(currentUser.id);
      final availableVehicles = allVehicles.where((v) => !v.isListedForSale).toList();
      setState(() {
        _userVehicles = availableVehicles;
        _isLoading = false;
      });
    } else {
      setState(() {
        _userVehicles = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sell.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserVehicles,
              child: _userVehicles.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _userVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _userVehicles[index];
                        return _buildVehicleCard(vehicle);
                      },
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
              Icons.sell_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'sell.noVehicles'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'sell.noVehiclesDesc'.tr(),
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

  Widget _buildVehicleCard(UserVehicle vehicle) {
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
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Builder(
                    builder: (context) {
                      final imageUrl = (vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty)
                          ? vehicle.imageUrl
                          : VehicleUtils.getVehicleImage(vehicle.brand, vehicle.model, vehicleId: vehicle.id);
                      
                      if (imageUrl != null) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            imageUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              final correctPath = VehicleUtils.getVehicleImage(vehicle.brand, vehicle.model, vehicleId: vehicle.id);
                              
                              if (correctPath != null && correctPath != imageUrl) {
                                return Image.asset(
                                  correctPath,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.directions_car,
                                    color: Colors.deepPurple,
                                    size: 40,
                                  ),
                                );
                              }
                              
                              return const Icon(
                                Icons.directions_car,
                                color: Colors.deepPurple,
                                size: 40,
                              );
                            },
                          ),
                        );
                      } else {
                        return const Icon(
                          Icons.directions_car,
                          color: Colors.deepPurple,
                          size: 40,
                        );
                      }
                    }
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
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sell.purchasePrice'.tr(),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'sell.ownershipDuration'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle.daysOwned} ${'sell.days'.tr()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.local_gas_station, 'vehicleAttributes.${vehicle.fuelType}'.tr()),
                _buildInfoChip(Icons.settings, 'vehicleAttributes.${vehicle.transmission}'.tr()),
                _buildInfoChip(Icons.palette, 'colors.${vehicle.color}'.tr()),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateListingScreen(vehicle: vehicle),
                    ),
                  );
                  if (result == true && context.mounted) {
                    _loadUserVehicles(); // İlan oluşturulduysa listeyi yenile
                  }
                },
                icon: const Icon(Icons.sell),
                label: Text('sell.listForSaleButton'.tr()),
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
}

