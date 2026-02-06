import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../utils/brand_colors.dart';
import 'package:intl/intl.dart';
import 'create_listing_screen.dart';
import '../utils/vehicle_utils.dart';
import '../mixins/auto_refresh_mixin.dart';
import 'package:cebinden_app/widgets/modern_alert_dialog.dart';
import '../services/skill_service.dart';
import '../services/daily_quest_service.dart';
import '../models/daily_quest_model.dart';
import 'package:lottie/lottie.dart';
import '../widgets/game_image.dart';
import '../services/ad_service.dart';
import '../services/xp_service.dart';
import '../widgets/level_up_dialog.dart';
import '../widgets/modern_button.dart';

import '../services/staff_service.dart';

class MyVehiclesScreen extends StatefulWidget {
  final String?
  selectedBrand; // null = marka listesi göster, brand = o markanın araçlarını göster

  const MyVehiclesScreen({super.key, this.selectedBrand});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen>
    with RouteAware, AutoRefreshMixin {
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  final XPService _xpService = XPService();
  final StaffService _staffService = StaffService();

  User? _currentUser;
  List<UserVehicle> _allVehicles = [];
  List<UserVehicle> _personalVehicles = [];
  List<UserVehicle> _commercialVehicles = [];
  bool _isLoading = true;
  bool _hasStaff = false;

  // Marka bazında gruplandırılmış araçlar
  Map<String, List<UserVehicle>> _personalByBrand = {};
  Map<String, List<UserVehicle>> _commercialByBrand = {};
  StreamSubscription? _vehicleUpdateSubscription;

  @override
  int? get tabIndex => 2; // MainScreen'deki index

  @override
  void refresh() {
    _loadMyVehicles();
  }

  @override
  void initState() {
    super.initState();
    _loadMyVehicles();
    _vehicleUpdateSubscription = _db.onVehicleUpdate.listen((_) {
      _loadMyVehicles();
    });
  }

  @override
  void dispose() {
    _vehicleUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMyVehicles() async {
    setState(() => _isLoading = true);

    final user = await _authService.getCurrentUser();
    if (user != null) {
      final vehicles = await _db.getUserActiveVehicles(user.id);

      // Personel kontrolü
      final hasStaff = _staffService.myStaff.isNotEmpty;

      // Araçları ayır
      final personal = vehicles.where((v) => !v.isStaffPurchased).toList();
      final commercial = vehicles.where((v) => v.isStaffPurchased).toList();

      // Markaya göre grupla (Helper function)
      Map<String, List<UserVehicle>> groupByBrand(List<UserVehicle> list) {
        final Map<String, List<UserVehicle>> grouped = {};
        for (var vehicle in list) {
          if (!grouped.containsKey(vehicle.brand)) {
            grouped[vehicle.brand] = [];
          }
          grouped[vehicle.brand]!.add(vehicle);
        }
        return grouped;
      }

      setState(() {
        _currentUser = user;
        _allVehicles = vehicles;
        _personalVehicles = personal;
        _commercialVehicles = commercial;
        _personalByBrand = groupByBrand(personal);
        _commercialByBrand = groupByBrand(commercial);
        _hasStaff = hasStaff;
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
        if (!_hasStaff && _commercialVehicles.isEmpty) {
          return _buildScaffold(
            context: context,
            title: widget.selectedBrand != null
                ? widget.selectedBrand!
                : 'home.myVehicles'.tr(),
            body: _buildGarageContent(_allVehicles, _groupAllByBrand()),
            limitCount: _allVehicles.length,
          );
        }

        return DefaultTabController(
          length: 2,
          child: _buildScaffold(
            context: context,
            title: widget.selectedBrand != null
                ? widget.selectedBrand!
                : 'garage.title'.tr(),
            bottom: TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'garage.tab_personal'.tr()),
                Tab(text: 'garage.tab_commercial'.tr()),
              ],
            ),
            body: TabBarView(
              children: [
                _buildGarageContent(
                  _personalVehicles,
                  _personalByBrand,
                  limitCount: _personalVehicles.length,
                  emptyMessage:
                      'Henüz şahsi aracınız yok. "Araç Al" menüsünden veya galeriden araç satın alabilirsiniz.',
                ),
                _buildGarageContent(
                  _commercialVehicles,
                  _commercialByBrand,
                  limitCount: _commercialVehicles.length,
                  emptyMessage:
                      'Personeliniz henüz ticari amaçlı araç satın almadı. Satın Alımcı işe alarak otomatik araç toplayabilirsiniz.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, List<UserVehicle>> _groupAllByBrand() {
    final Map<String, List<UserVehicle>> grouped = {};
    for (var vehicle in _allVehicles) {
      if (!grouped.containsKey(vehicle.brand)) {
        grouped[vehicle.brand] = [];
      }
      grouped[vehicle.brand]!.add(vehicle);
    }
    return grouped;
  }

  Widget _buildScaffold({
    required BuildContext context,
    required String title,
    required Widget body,
    PreferredSizeWidget? bottom,
    int? limitCount,
  }) {
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          return false;
        }
        return true;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.deepPurple.withOpacity(0.9),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: bottom,
        ),
        body: Container(
          decoration: BoxDecoration(
            image: GameDecorationImage(
              assetPath: 'assets/images/general_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : limitCount != null
                ? Column(
                    children: [
                      _buildLimitIndicator(limitCount),
                      Expanded(child: body),
                    ],
                  )
                : body,
          ),
        ),
      ),
    );
  }

  Widget _buildLimitIndicator(int currentCount) {
    if (_currentUser == null) return const SizedBox.shrink();

    final baseLimit = _currentUser!.garageLimit;
    final totalLimit = baseLimit;
    final isFull = currentCount >= totalLimit;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFull
                  ? Colors.red.withOpacity(0.1)
                  : Colors.deepPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.garage,
              color: isFull ? Colors.red : Colors.deepPurple,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'misc.vehicleLimit'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$currentCount / $totalLimit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isFull ? Colors.red : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalLimit > 0 ? currentCount / totalLimit : 0.0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFull ? Colors.red : Colors.deepPurple,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Marka listesi (1. seviye)
  Widget _buildBrandList(Map<String, List<UserVehicle>> vehiclesByBrand) {
    return RefreshIndicator(
      onRefresh: _loadMyVehicles,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: vehiclesByBrand.length,
        itemBuilder: (context, index) {
          final brand = vehiclesByBrand.keys.elementAt(index);
          final vehicles = vehiclesByBrand[brand]!;
          return _buildBrandCard(brand, vehicles.length);
        },
      ),
    );
  }

  // Belirli bir markanın araç listesi (2. seviye)
  Widget _buildVehicleList(List<UserVehicle> vehicles) {
    if (vehicles.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: _loadMyVehicles,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          return _buildVehicleCard(vehicle);
        },
      ),
    );
  }

  // Yeni method: Garage content controller
  Widget _buildGarageContent(
    List<UserVehicle> vehicles,
    Map<String, List<UserVehicle>> vehiclesByBrand, {
    int? limitCount,
    String? emptyMessage,
  }) {
    // Boş durum
    if (vehicles.isEmpty) {
      final emptyStateWidget = _buildEmptyState(message: emptyMessage);

      if (limitCount != null) {
        return Column(
          children: [
            _buildLimitIndicator(limitCount),
            Expanded(child: emptyStateWidget),
          ],
        );
      }
      return emptyStateWidget;
    }

    Widget content;

    // Marka seçili mi?
    if (widget.selectedBrand != null) {
      // Markanın araçlarını bul
      List<UserVehicle> brandVehicles =
          vehiclesByBrand[widget.selectedBrand] ?? [];

      // Fuzzy match
      if (brandVehicles.isEmpty) {
        final key = vehiclesByBrand.keys.firstWhere(
          (k) =>
              k.toLowerCase().trim() ==
              widget.selectedBrand!.toLowerCase().trim(),
          orElse: () => '',
        );
        if (key.isNotEmpty) {
          brandVehicles = vehiclesByBrand[key]!;
        }
      }

      if (brandVehicles.isEmpty) {
        // Marka seçili ama bu tab'da/listede yok
        content = _buildEmptyBrandState(widget.selectedBrand!, vehicles.length);
      } else {
        content = _buildVehicleList(brandVehicles);
      }
    } else {
      // Marka seçili değil, marka listesi göster
      content = _buildBrandList(vehiclesByBrand);
    }

    if (limitCount != null) {
      return Column(
        children: [
          _buildLimitIndicator(limitCount),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  // Updated Empty State
  Widget _buildEmptyState({String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon removed as requested
            Text(
              message ?? 'vehicles.noVehicles'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500, // Slightly bolder but not bold
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBrandState(String brand, int totalCount) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              '$brand markalı araç bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bu listede $totalCount araç var ancak bu markada araç yok.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyVehiclesScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: Text('Tüm Araçları Göster'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandCard(String brand, int vehicleCount) {
    final brandColor = BrandColors.getColor(
      brand,
      defaultColor: Colors.deepPurple,
    );

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyVehiclesScreen(selectedBrand: brand),
          ),
        );
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
                child: GameImage(
                  assetPath: 'assets/images/brands/${brand.toLowerCase()}.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  // errorBuilder handled by GameImage or we can add it if needed
                ),
              ),
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge (Araç Sayısı)
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
                        '$vehicleCount',
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
                        vehicleCount == 1
                            ? '1 ${'misc.vehicle'.tr()}'
                            : '$vehicleCount ${'misc.vehicle'.tr()}',
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

  Widget _buildVehicleCard(UserVehicle vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
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
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Builder(
                    builder: (context) {
                      final imageUrl =
                          (vehicle.imageUrl != null &&
                              vehicle.imageUrl!.isNotEmpty)
                          ? vehicle.imageUrl
                          : VehicleUtils.getVehicleImage(
                              vehicle.brand,
                              vehicle.model,
                              vehicleId: vehicle.id,
                            );

                      if (imageUrl != null) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GameImage(
                            assetPath: imageUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Eğer yüklenen resim hatalıysa (örn: eski veritabanı kayıtları),
                              // VehicleUtils ile doğrusunu bulmaya çalış
                              final correctPath = VehicleUtils.getVehicleImage(
                                vehicle.brand,
                                vehicle.model,
                                vehicleId: vehicle.id,
                              );

                              if (correctPath != null &&
                                  correctPath != imageUrl) {
                                return GameImage(
                                  assetPath: correctPath,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.directions_car,
                                        size: 40,
                                        color: Colors.deepPurple,
                                      ),
                                );
                              }

                              return const Icon(
                                Icons.directions_car,
                                size: 40,
                                color: Colors.deepPurple,
                              );
                            },
                          ),
                        );
                      } else {
                        return const Icon(
                          Icons.directions_car,
                          size: 40,
                          color: Colors.deepPurple,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Araç Detayları
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.fullName.replaceAll(
                          'Serisi',
                          'vehicles.series'.tr(),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Satışta Badge'i (eğer satışta ise)
                          if (vehicle.isListedForSale)
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
                              'vehicles.${vehicle.fuelType}'.tr(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
                              'vehicles.${vehicle.transmission}'.tr(),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ModernButton(
                  text: 'misc.vehicleDetails'.tr(),
                  onPressed: () {
                    _showVehicleDetailsDialog(vehicle);
                  },
                  isOutlined: true,
                  color: Colors.deepPurple,
                ),
                // "Sat" butonu sadece araç satışta DEĞİLse görünsün
                if (!vehicle.isListedForSale) ...[
                  const SizedBox(height: 12),
                  ModernButton(
                    text: 'misc.sellVehicle'.tr(),
                    onPressed: () async {
                      // Satışa çıkarma ekranına git
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateListingScreen(vehicle: vehicle),
                        ),
                      );

                      // Eğer satışa çıkarma başarılıysa listeyi yenile
                      if (result == true) {
                        await _loadMyVehicles();
                      }
                    },
                    color: Colors.green,
                    gradientColors: [
                      Colors.green.shade400,
                      Colors.green.shade700,
                    ],
                  ),

                  // Hızlı Sat Butonu (Eğer yetenek açıksa)
                  if (_currentUser != null)
                    Builder(
                      builder: (context) {
                        final level = SkillService().getSkillLevel(
                          _currentUser!,
                          SkillService.skillQuickSell,
                        );
                        if (level > 0) {
                          final margin =
                              SkillService.quickSellMargins[level] ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ModernButton(
                              text:
                                  '${'skills.quickSell'.tr()} (${'skills.quickSellProfit'.trParams({'percent': '%${(margin * 100).toInt()}'})})',
                              onPressed: () =>
                                  _showQuickSellConfirmation(vehicle),
                              color: Colors.orange,
                              gradientColors: [
                                Colors.orange.shade400,
                                Colors.deepOrange.shade700,
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                ],
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
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  String _formatDate(DateTime date) {
    final currentLang = LocalizationService().currentLanguage;
    final locale = currentLang == 'tr' ? 'tr_TR' : 'en_US';
    return DateFormat('dd MMM yyyy', locale).format(date);
  }

  void _showVehicleDetailsDialog(UserVehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                            vehicle.fullName.replaceAll(
                              'Serisi',
                              'vehicles.series'.tr(),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${vehicle.year} • ${vehicle.brand}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Technical specs removed as per user request
                      // Purchase details removed as per user request
                      if (vehicle.hasAccidentRecord) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'vehicles.accidentRecord'.tr(),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Teknik Özellikler
                      _buildSectionTitle('vehicles.technicalSpecs'.tr()),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildDetailRow(
                          Icons.local_gas_station,
                          'vehicles.fuelType'.tr(),
                          'vehicles.${vehicle.fuelType}'.tr(),
                          Colors.orange,
                        ),
                        _buildDetailRow(
                          Icons.settings,
                          'vehicles.transmission'.tr(),
                          'vehicles.${vehicle.transmission}'.tr(),
                          Colors.teal,
                        ),
                        _buildDetailRow(
                          Icons.speed,
                          'vehicles.engineSize'.tr(),
                          '${vehicle.engineSize} L',
                          Colors.red,
                        ),
                        _buildDetailRow(
                          Icons.compare_arrows,
                          'vehicles.driveType'.tr(),
                          'vehicles.${vehicle.driveType}'.tr(),
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
                          vehicle.hasWarranty
                              ? 'common.yes'.tr()
                              : 'common.no'.tr(),
                          vehicle.hasWarranty ? Colors.green : Colors.grey,
                        ),
                        _buildDetailRow(
                          Icons.car_crash,
                          'vehicles.accidentRecord'.tr(),
                          vehicle.hasAccidentRecord
                              ? 'common.yes'.tr()
                              : 'common.no'.tr(),
                          vehicle.hasAccidentRecord ? Colors.red : Colors.green,
                        ),
                        _buildDetailRow(
                          Icons.star,
                          'myVehicles.listingScore'.tr(),
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
                            'myVehicles.potentialProfitLoss'.tr(),
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
                                    Icon(
                                      Icons.description,
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

  Widget _buildSimpleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
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
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
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
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
    final remainingUses = skillService.getRemainingDailyUses(
      _currentUser!,
      SkillService.skillQuickSell,
    );

    if (remainingUses <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('skills.dailyLimitReached'.tr())),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final level = skillService.getSkillLevel(
      _currentUser!,
      SkillService.skillQuickSell,
    );
    final margin = SkillService.quickSellMargins[level] ?? 0.0;
    final sellPrice = (vehicle.purchasePrice * (1 + margin)).round();
    final profit = sellPrice - vehicle.purchasePrice;

    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'skills.quickSellConfirm'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'skills.quickSellConfirmDesc'.trParams({
                'price': _formatCurrency(sellPrice.toDouble()),
              }),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.greenAccent),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'skills.quickSellProfit'.trParams({
                          'percent': '%${(margin * 100).toInt()}',
                        }),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                      Text(
                        '+${_formatCurrency(profit.toDouble())} TL',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${'skills.remainingUses'.tr()}: $remainingUses/3',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        buttonText: 'skills.quickSell'.tr(),
        onPressed: () async {
          Navigator.pop(context);
          await _processQuickSell(vehicle, sellPrice);
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
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
      await SkillService().recordSkillUsage(
        _currentUser!.id,
        SkillService.skillQuickSell,
      );

      // 🆕 Günlük Görev Güncellemesi (Araç Satma)
      await DailyQuestService().updateProgress(
        _currentUser!.id,
        QuestType.sellVehicle,
        1,
      );

      // 4. XP Kazandır ve Level Up Kontrolü
      final profit = sellPrice - vehicle.purchasePrice;
      final xpResult = await _xpService.onVehicleSale(_currentUser!.id, profit);

      // 5. Animasyon
      await _playSoldAnimation();

      // 6. Level Up varsa dialog göster
      if (xpResult.leveledUp && xpResult.rewards != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => LevelUpDialog(reward: xpResult.rewards!),
        );
        // Level up sonrası zorunlu reklam
        await AdService().showInterstitialAd(force: true);
      } else {
        // Reklam göster (eğer hazırsa ve kullanıcıda reklam kaldırma yoksa)
        if (mounted) {
          AdService().showInterstitialAd(
            hasNoAds: _currentUser?.hasNoAds ?? false,
          );
        }
      }

      // 5. Listeyi yenile
      await _loadMyVehicles();

      // Kullanıcıyı güncelle (bakiye için)
      final updatedUser = await _authService.getCurrentUser();
      if (updatedUser != null) {
        setState(() => _currentUser = updatedUser);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          content: Text('Hata: $e'),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
