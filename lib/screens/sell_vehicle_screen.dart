import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_vehicle_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';
import 'create_listing_screen.dart';
import 'main_screen.dart';
import '../utils/vehicle_utils.dart';
import '../services/skill_service.dart';
import '../models/user_model.dart';
import 'package:lottie/lottie.dart';

class SellVehicleScreen extends StatefulWidget {
  const SellVehicleScreen({super.key});

  @override
  State<SellVehicleScreen> createState() => _SellVehicleScreenState();
}

class _SellVehicleScreenState extends State<SellVehicleScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();
  List<UserVehicle> _userVehicles = [];
  User? _currentUser;
  bool _isLoading = true;
  StreamSubscription? _vehicleUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserVehicles();
    
    // Veritabanı güncellemelerini dinle
    _vehicleUpdateSubscription = _db.onVehicleUpdate.listen((_) {
      _loadUserVehicles();
    });
  }

  @override
  void dispose() {
    _vehicleUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserVehicles() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // Sadece satılmamış ve satışa çıkarılmamış araçları getir
        final allVehicles = await _db.getUserActiveVehicles(currentUser.id);
        final availableVehicles = allVehicles.where((v) => !v.isListedForSale).toList();
        
        if (mounted) {
          setState(() {
            _userVehicles = availableVehicles;
            _currentUser = currentUser;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userVehicles = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user vehicles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vehicles: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          return false;
        }
        return true;
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text('sell.title'.tr()),
        actions: [

        ],
        elevation: 0,
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
              color: Colors.black,
            ),
            const SizedBox(height: 24),
            Text(
              'sell.noVehicles'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'sell.noVehiclesDesc'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
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
                          icon: const Icon(Icons.sell, size: 18),
                          label: Text(
                            'sell.listForSaleButton'.tr(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.7),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      // Hızlı Sat Butonu (Eğer yetenek açıksa)
                      if (_currentUser != null)
                        Builder(
                          builder: (context) {
                            final level = SkillService().getSkillLevel(_currentUser!, SkillService.skillQuickSell);
                            if (level > 0) {
                              final margin = SkillService.quickSellMargins[level] ?? 0.0;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ElevatedButton(
                                    onPressed: () => _showQuickSellConfirmation(vehicle),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade800.withOpacity(0.7),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 48),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: FittedBox(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.flash_on, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            'skills.quickSell'.tr(),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${'skills.quickSellProfit'.trParams({'percent': '%${(margin * 100).toInt()}'})})',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
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

  Future<void> _playSoldAnimation() async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Lottie.asset(
          'assets/animations/selling_car.json',
          width: 300,
          height: 300,
          repeat: false,
          onLoaded: (composition) {
            Future.delayed(composition.duration, () {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _showQuickSellConfirmation(UserVehicle vehicle) async {
    if (_currentUser == null) return;

    final skillService = SkillService();
    final remainingUses = skillService.getRemainingDailyUses(_currentUser!, SkillService.skillQuickSell);

    if (remainingUses <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('skills.dailyLimitReached'.tr())),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final level = skillService.getSkillLevel(_currentUser!, SkillService.skillQuickSell);
    final margin = SkillService.quickSellMargins[level] ?? 0.0;
    final sellPrice = (vehicle.purchasePrice * (1 + margin)).round();
    final profit = sellPrice - vehicle.purchasePrice;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('skills.quickSellConfirm'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('skills.quickSellConfirmDesc'.trParams({'price': _formatCurrency(sellPrice.toDouble())})),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.green),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'skills.quickSellProfit'.trParams({'percent': '%${(margin * 100).toInt()}'}),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text(
                        '+${_formatCurrency(profit.toDouble())} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${'skills.remainingUses'.tr()}: $remainingUses/3',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _processQuickSell(vehicle, sellPrice);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: Text('skills.quickSell'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _processQuickSell(UserVehicle vehicle, int sellPrice) async {
    setState(() => _isLoading = true);
    try {
      // 1. Bakiyeyi güncelle
      final newBalance = _currentUser!.balance + sellPrice;
      await _db.updateUser(_currentUser!.id, {'balance': newBalance});

      // 2. Aracı satıldı olarak işaretle
      await _db.sellUserVehicle(vehicle.id, sellPrice.toDouble());

      // 3. Yetenek kullanımını kaydet
      await SkillService().recordSkillUsage(_currentUser!.id, SkillService.skillQuickSell);

      // 4. Animasyon
      await _playSoldAnimation();

      // 5. Listeyi yenile
      await _loadUserVehicles();
      
      // Kullanıcıyı güncelle (bakiye için)
      final updatedUser = await _authService.getCurrentUser();
      if (updatedUser != null) {
        setState(() => _currentUser = updatedUser);
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

