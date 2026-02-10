// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/localization_service.dart';
import '../services/market_refresh_service.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../models/vehicle_model.dart';
import '../widgets/vehicle_image.dart';
import '../widgets/game_image.dart';
import 'vehicle_detail_screen.dart';
import 'dart:convert';
import '../services/settings_helper.dart';

class VehicleListScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;
  final String? brandName; // null = tüm markalar
  final String? modelName; // null = tüm modeller

  const VehicleListScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    this.brandName,
    this.modelName,
  });

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final MarketRefreshService _marketService = MarketRefreshService();

  List<Vehicle> allVehicles = []; // Tüm araçlar
  List<Vehicle> filteredVehicles = []; // Filtrelenmiş araçlar

  // Filtre durumları (Backend değerlerini saklayacağız)
  Set<String> selectedFuelTypes = {};
  Set<String> selectedTransmissions = {};
  Set<String> selectedMileageRanges = {};
  Set<String> selectedPriceRanges = {};
  Set<String> selectedYearRanges = {};
  String? _selectedSortOption; // 'price_asc', 'price_desc'
  double? _currentBalance; // Kullanıcının mevcut bakiyesi
  List<SavedFilter> savedFilters = []; // Kayıtlı filtreler

  // Yakıt tipi mapping (backend değerleri)
  final Map<String, String> _fuelTypeMapping = {
    'Benzin': 'vehicles.fuelGasoline',
    'Dizel': 'vehicles.fuelDiesel',
  };

  // Vites tipi mapping (backend değerleri)
  final Map<String, String> _transmissionMapping = {
    'Manuel': 'vehicles.transmissionManual',
    'Otomatik': 'vehicles.transmissionAutomatic',
  };

  StreamSubscription? _userUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadUserBalance();
    _loadSavedFilters();

    // Bakiye güncellemelerini dinle
    _userUpdateSubscription = DatabaseHelper().onUserUpdate.listen((_) {
      _loadUserBalance();
    });
  }

  @override
  void dispose() {
    _userUpdateSubscription?.cancel();
    super.dispose();
  }

  // Kullanıcı bakiyesini yükle
  Future<void> _loadUserBalance() async {
    final user = await AuthService().getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _currentBalance = user.balance;
      });
    }
  }

  // Kayıtlı filtreleri yükle
  Future<void> _loadSavedFilters() async {
    final settings = await SettingsHelper.getInstance();
    final savedJson = await settings.getSavedFilters();
    if (mounted) {
      setState(() {
        savedFilters = savedJson
            .map((jsonStr) => SavedFilter.fromJson(jsonDecode(jsonStr)))
            .toList();
      });
    }
  }

  // Filtreyi kaydet
  Future<void> _saveFilter(String name) async {
    final newFilter = SavedFilter(
      name: name,
      fuelTypes: Set.from(selectedFuelTypes),
      transmissions: Set.from(selectedTransmissions),
      mileageRanges: Set.from(selectedMileageRanges),
      priceRanges: Set.from(selectedPriceRanges),
      yearRanges: Set.from(selectedYearRanges),
      sortOption: _selectedSortOption,
    );

    setState(() {
      savedFilters.add(newFilter);
    });

    final settings = await SettingsHelper.getInstance();
    final savedJson = savedFilters.map((f) => jsonEncode(f.toJson())).toList();
    await settings.setSavedFilters(savedJson);
  }

  // Kayıtlı filtreyi uygula
  void _applySavedFilter(SavedFilter filter) {
    setState(() {
      selectedFuelTypes = Set.from(filter.fuelTypes);
      selectedTransmissions = Set.from(filter.transmissions);
      selectedMileageRanges = Set.from(filter.mileageRanges);
      selectedPriceRanges = Set.from(filter.priceRanges);
      selectedYearRanges = Set.from(filter.yearRanges);
      _selectedSortOption = filter.sortOption;
      _applyFilters();
    });
  }

  // Kayıtlı filtreyi sil
  Future<void> _deleteSavedFilter(SavedFilter filter) async {
    setState(() {
      savedFilters.remove(filter);
      _clearFilters(); // Filtre silindiğinde varsayılana dön
    });

    final settings = await SettingsHelper.getInstance();
    final savedJson = savedFilters.map((f) => jsonEncode(f.toJson())).toList();
    await settings.setSavedFilters(savedJson);
  }

  // Araçları market servisinden yükle
  void _loadVehicles() {
    setState(() {
      allVehicles = _marketService.getActiveListings(
        brand: widget.brandName,
        model: widget.modelName,
      );
      filteredVehicles = List.from(allVehicles);
    });
  }

  // Filtreleri uygula
  void _applyFilters() {
    setState(() {
      filteredVehicles = allVehicles.where((vehicle) {
        // Yakıt tipi filtresi
        if (selectedFuelTypes.isNotEmpty &&
            !selectedFuelTypes.contains(vehicle.fuelType)) {
          return false;
        }

        // Vites filtresi
        if (selectedTransmissions.isNotEmpty &&
            !selectedTransmissions.contains(vehicle.transmission)) {
          return false;
        }

        // Kilometre filtresi
        if (selectedMileageRanges.isNotEmpty) {
          bool matchesAny = false;
          for (final range in selectedMileageRanges) {
            if (range == '0-50k' && vehicle.mileage <= 50000) matchesAny = true;
            if (range == '50k-100k' &&
                (vehicle.mileage > 50000 && vehicle.mileage <= 100000)) {
              matchesAny = true;
            }
            if (range == '100k-150k' &&
                (vehicle.mileage > 100000 && vehicle.mileage <= 150000)) {
              matchesAny = true;
            }
            if (range == '150k+' && vehicle.mileage > 150000) matchesAny = true;
          }
          if (!matchesAny) return false;
        }

        // Fiyat filtresi
        if (selectedPriceRanges.isNotEmpty) {
          bool matchesAny = false;
          for (final range in selectedPriceRanges) {
            if (range == '0-300k' && vehicle.price <= 300000) matchesAny = true;
            if (range == '300k-500k' &&
                (vehicle.price > 300000 && vehicle.price <= 500000)) {
              matchesAny = true;
            }
            if (range == '500k-700k' &&
                (vehicle.price > 500000 && vehicle.price <= 700000)) {
              matchesAny = true;
            }
            if (range == '700k+' && vehicle.price > 700000) matchesAny = true;
          }
          if (!matchesAny) return false;
        }

        // Yıl filtresi
        if (selectedYearRanges.isNotEmpty) {
          bool matchesAny = false;
          for (final range in selectedYearRanges) {
            if (range == '2026' && vehicle.year == 2026) matchesAny = true;
            if (range == '2024-2025' &&
                (vehicle.year >= 2024 && vehicle.year <= 2025)) {
              matchesAny = true;
            }
            if (range == '2020-2023' &&
                (vehicle.year >= 2020 && vehicle.year <= 2023)) {
              matchesAny = true;
            }
            if (range == '2015-2019' &&
                (vehicle.year >= 2015 && vehicle.year <= 2019)) {
              matchesAny = true;
            }
            if (range == '2015 öncesi' && vehicle.year < 2015) {
              matchesAny = true;
            }
          }
          if (!matchesAny) return false;
        }

        return true;
      }).toList();

      // Sıralama
      if (_selectedSortOption == 'price_asc') {
        filteredVehicles.sort((a, b) => a.price.compareTo(b.price));
      } else if (_selectedSortOption == 'price_desc') {
        filteredVehicles.sort((a, b) => b.price.compareTo(a.price));
      }
    });
  }

  // Tüm filtreleri temizle
  void _clearFilters() {
    setState(() {
      selectedFuelTypes.clear();
      selectedTransmissions.clear();
      selectedMileageRanges.clear();
      selectedPriceRanges.clear();
      selectedYearRanges.clear();
      filteredVehicles = allVehicles;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder ile dil değişikliklerini dinle
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        return Scaffold(
          // backgroundColor: Colors.grey[100], // Arka plan resmi kullanıldığı için kaldırıldı
          appBar: AppBar(
            title: Text(widget.categoryName),
            actions: [],
            backgroundColor: widget.categoryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Container(
            decoration: BoxDecoration(
              image: GameDecorationImage(
                assetPath: 'assets/images/general_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                // Filtreler (Üstte sabit)
                Container(
                  color: Colors.white.withValues(alpha: 0.9), // Hafif şeffaflık
                  child: Column(
                    children: [
                      // Ana Filtre Kategorileri
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Yakıt Tipi
                            _buildCategoryFilter(
                              'vehicles.filterFuelType'.tr(),
                              selectedFuelTypes.isNotEmpty,
                              selectedFuelTypes.length,
                              () => _showFuelTypeFilter(context),
                            ),
                            const SizedBox(width: 8),

                            // Vites
                            _buildCategoryFilter(
                              'vehicles.filterTransmission'.tr(),
                              selectedTransmissions.isNotEmpty,
                              selectedTransmissions.length,
                              () => _showTransmissionFilter(context),
                            ),
                            const SizedBox(width: 8),

                            // Kilometre
                            _buildCategoryFilter(
                              'vehicles.filterMileage'.tr(),
                              selectedMileageRanges.isNotEmpty,
                              selectedMileageRanges.length,
                              () => _showMileageFilter(context),
                            ),
                            const SizedBox(width: 8),

                            // Yıl
                            _buildCategoryFilter(
                              'vehicles.filterYear'.tr(),
                              selectedYearRanges.isNotEmpty,
                              selectedYearRanges.length,
                              () => _showYearFilter(context),
                            ),
                            const SizedBox(width: 8),

                            // Fiyat (En sağa taşındı)
                            _buildCategoryFilter(
                              'vehicles.filterPrice'.tr(),
                              selectedPriceRanges.isNotEmpty,
                              selectedPriceRanges.length,
                              () => _showPriceFilter(context),
                            ),
                          ],
                        ),
                      ),

                      // Temizle ve Ekle Butonları (Alt Satır)
                      if (selectedFuelTypes.isNotEmpty ||
                          selectedTransmissions.isNotEmpty ||
                          selectedMileageRanges.isNotEmpty ||
                          selectedPriceRanges.isNotEmpty ||
                          selectedYearRanges.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              // Temizle Butonu
                              InkWell(
                                onTap: _clearFilters,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.red[300]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.clear,
                                        size: 16,
                                        color: Colors.red[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'vehicles.clearFilters'.tr(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.red[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Ekle Butonu
                              InkWell(
                                onTap: () => _showSaveFilterDialog(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Ekle',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Kayıtlı Filtreler Bölümü
                      if (savedFilters.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: savedFilters.map((filter) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () =>
                                                _applySavedFilter(filter),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(16),
                                                  bottomLeft: Radius.circular(
                                                    16,
                                                  ),
                                                ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 12,
                                                top: 6,
                                                bottom: 6,
                                                right: 8,
                                              ),
                                              child: Text(
                                                filter.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () =>
                                                _deleteSavedFilter(filter),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topRight: Radius.circular(16),
                                                  bottomRight: Radius.circular(
                                                    16,
                                                  ),
                                                ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4,
                                                right: 8,
                                                top: 6,
                                                bottom: 6,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 10,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                      // Sonuç Sayısı Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        color: widget.categoryColor.withValues(alpha: 0.1),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: widget.categoryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${filteredVehicles.length} ${'vehicles.foundVehicles'.tr()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Sıralama Filtresi
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.9,
                    ), // Hafif şeffaflık
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Icon(Icons.sort, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'vehicles.sortBy'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildSortChip(
                          'vehicles.sortPriceLowToHigh'.tr(),
                          'price_asc',
                        ),
                        const SizedBox(width: 8),
                        _buildSortChip(
                          'vehicles.sortPriceHighToLow'.tr(),
                          'price_desc',
                        ),
                      ],
                    ),
                  ),
                ),

                // Bakiye Göstergesi
                if (_currentBalance != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.green.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${'purchase.currentBalance'.tr()}:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatCurrency(_currentBalance!)} TL',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Araç Listesi
                Expanded(
                  child: filteredVehicles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'vehicles.noVehiclesFiltered'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _clearFilters,
                                child: Text('vehicles.clearFilters'.tr()),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredVehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = filteredVehicles[index];
                            return _buildVehicleCard(vehicle);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          // Araç detayına git ve satın alma sonucunu bekle
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VehicleDetailScreen(vehicle: vehicle),
            ),
          );

          // Listeyi yenile (Ekspertiz durumu değişmiş olabilir veya araç satılmış olabilir)
          if (context.mounted) {
            _loadVehicles();
            _applyFilters();
            _loadUserBalance(); // Bakiyeyi güncelle
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Araç Resmi (Sol tarafta)
            Container(
              width: 120,
              decoration: BoxDecoration(
                color: widget.categoryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Center(
                child:
                    (vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: VehicleImage(
                          vehicle: vehicle,
                          width: 120,
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_car,
                            size: 50,
                            color: widget.categoryColor.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 4),
                          if (vehicle.color != 'Standart')
                            Text(
                              vehicle.color,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
              ),
            ),

            // Araç Bilgileri (Sağ tarafta)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Üst Kısım: Araç Adı ve Yıl
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle.fullName.replaceAll(
                              'Serisi',
                              'vehicles.series'.tr(),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            vehicle.year.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.categoryColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Orta Kısım: Özellikler
                    Row(
                      children: [
                        _buildCompactFeature(
                          Icons.speed,
                          '${_formatNumber(vehicle.mileage)} km',
                        ),
                        const SizedBox(width: 12),
                        _buildCompactFeature(
                          Icons.local_gas_station,
                          vehicle.fuelType,
                        ),
                      ],
                    ),

                    // Alt Kısım: Konum ve Fiyat
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Konum
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              vehicle.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        // Fiyat
                        Text(
                          '${_formatCurrency(vehicle.price)} TL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.categoryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFeature(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }

  // Kategori Filtre Butonu
  Widget _buildCategoryFilter(
    String label,
    bool hasSelection,
    int count,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: hasSelection
              ? widget.categoryColor.withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasSelection ? widget.categoryColor : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: hasSelection ? widget.categoryColor : Colors.grey[700],
                fontWeight: hasSelection ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (hasSelection) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.categoryColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: hasSelection ? widget.categoryColor : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  // Mapping ile Dropdown Filter (Multi-select)
  void _showDropdownFilterWithMapping(
    BuildContext context, {
    required String title,
    required List<String> displayOptions,
    required List<String> backendValues,
    required Set<String> selectedDisplayValues,
    required Function(Set<String>) onUpdate,
  }) {
    final Set<String> tempSelectedValues = Set.from(selectedDisplayValues);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Başlık
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.filter_alt,
                                color: widget.categoryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          if (tempSelectedValues.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.categoryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${tempSelectedValues.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Seçenekler
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: displayOptions.length,
                        itemBuilder: (context, index) {
                          final displayOption = displayOptions[index];
                          final isSelected = tempSelectedValues.contains(
                            displayOption,
                          );

                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  tempSelectedValues.remove(displayOption);
                                } else {
                                  tempSelectedValues.add(displayOption);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? widget.categoryColor.withValues(
                                        alpha: 0.1,
                                      )
                                    : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    displayOption,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isSelected
                                          ? widget.categoryColor
                                          : Colors.grey[700],
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? widget.categoryColor
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? widget.categoryColor
                                            : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Alt Butonlar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (tempSelectedValues.isNotEmpty)
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setDialogState(
                                    () => tempSelectedValues.clear(),
                                  );
                                  onUpdate({});
                                  Navigator.pop(dialogContext);
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'vehicles.clearFilters'.tr(),
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          if (tempSelectedValues.isNotEmpty)
                            const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                onUpdate(tempSelectedValues);
                                Navigator.pop(dialogContext);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.categoryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'vehicles.apply'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
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
          },
        );
      },
    );
  }

  // Genel Dropdown Filter (Multi-select)
  void _showDropdownFilter(
    BuildContext context, {
    required String title,
    required List<String> options,
    required Set<String> selectedValues,
    required VoidCallback onUpdate,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Başlık
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.filter_alt,
                                color: widget.categoryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          if (selectedValues.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.categoryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${selectedValues.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Seçenekler
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final isSelected = selectedValues.contains(option);

                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selectedValues.remove(option);
                                } else {
                                  selectedValues.add(option);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? widget.categoryColor.withValues(
                                        alpha: 0.1,
                                      )
                                    : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isSelected
                                          ? widget.categoryColor
                                          : Colors.grey[700],
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? widget.categoryColor
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? widget.categoryColor
                                            : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Alt Butonlar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (selectedValues.isNotEmpty)
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setDialogState(() => selectedValues.clear());
                                  setState(() => _applyFilters());
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'vehicles.clearFilters'.tr(),
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          if (selectedValues.isNotEmpty)
                            const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                onUpdate();
                                Navigator.pop(dialogContext);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.categoryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'vehicles.apply'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
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
          },
        );
      },
    );
  }

  // Yakıt Tipi Filtresi
  void _showFuelTypeFilter(BuildContext context) {
    // Backend değerlerinden çevrilmiş değerlere map
    final displayOptions = _fuelTypeMapping.keys
        .map((key) => _fuelTypeMapping[key]!.tr())
        .toList();
    final backendValues = _fuelTypeMapping.keys.toList();

    // Seçili backend değerlerini çevrilmiş değerlere dönüştür
    final displaySelected = selectedFuelTypes.map((backendValue) {
      final translationKey = _fuelTypeMapping[backendValue];
      return translationKey != null ? translationKey.tr() : backendValue;
    }).toSet();

    _showDropdownFilterWithMapping(
      context,
      title: 'vehicles.filterFuelType'.tr(),
      displayOptions: displayOptions,
      backendValues: backendValues,
      selectedDisplayValues: displaySelected,
      onUpdate: (newDisplayValues) {
        // Çevrilmiş değerlerden backend değerlerine dönüştür
        selectedFuelTypes.clear();
        for (final displayValue in newDisplayValues) {
          final backendValue = _fuelTypeMapping.entries
              .firstWhere(
                (entry) => entry.value.tr() == displayValue,
                orElse: () => const MapEntry('', ''),
              )
              .key;
          if (backendValue.isNotEmpty) {
            selectedFuelTypes.add(backendValue);
          }
        }
        setState(() => _applyFilters());
      },
    );
  }

  // Vites Filtresi
  void _showTransmissionFilter(BuildContext context) {
    // Backend değerlerinden çevrilmiş değerlere map
    final displayOptions = _transmissionMapping.keys
        .map((key) => _transmissionMapping[key]!.tr())
        .toList();
    final backendValues = _transmissionMapping.keys.toList();

    // Seçili backend değerlerini çevrilmiş değerlere dönüştür
    final displaySelected = selectedTransmissions.map((backendValue) {
      final translationKey = _transmissionMapping[backendValue];
      return translationKey != null ? translationKey.tr() : backendValue;
    }).toSet();

    _showDropdownFilterWithMapping(
      context,
      title: 'vehicles.filterTransmission'.tr(),
      displayOptions: displayOptions,
      backendValues: backendValues,
      selectedDisplayValues: displaySelected,
      onUpdate: (newDisplayValues) {
        // Çevrilmiş değerlerden backend değerlerine dönüştür
        selectedTransmissions.clear();
        for (final displayValue in newDisplayValues) {
          final backendValue = _transmissionMapping.entries
              .firstWhere(
                (entry) => entry.value.tr() == displayValue,
                orElse: () => const MapEntry('', ''),
              )
              .key;
          if (backendValue.isNotEmpty) {
            selectedTransmissions.add(backendValue);
          }
        }
        setState(() => _applyFilters());
      },
    );
  }

  // Kilometre Filtresi
  void _showMileageFilter(BuildContext context) {
    // Backend değerlerinden çevrilmiş değerlere map
    final Map<String, String> mileageOptions = {
      '0-50k': 'vehicles.mileageRange1'.tr(),
      '50k-100k': 'vehicles.mileageRange2'.tr(),
      '100k-150k': 'vehicles.mileageRange3'.tr(),
      '150k+': 'vehicles.mileageRange4'.tr(),
    };

    final displayOptions = mileageOptions.values.toList();
    final backendValues = mileageOptions.keys.toList();

    // Seçili backend değerlerini çevrilmiş değerlere dönüştür
    final displaySelected = selectedMileageRanges.map((backendValue) {
      return mileageOptions[backendValue] ?? backendValue;
    }).toSet();

    _showDropdownFilterWithMapping(
      context,
      title: 'vehicles.filterMileage'.tr(),
      displayOptions: displayOptions,
      backendValues: backendValues,
      selectedDisplayValues: displaySelected,
      onUpdate: (newDisplayValues) {
        selectedMileageRanges.clear();
        for (final displayValue in newDisplayValues) {
          final backendValue = mileageOptions.entries
              .firstWhere(
                (entry) => entry.value == displayValue,
                orElse: () => const MapEntry('', ''),
              )
              .key;
          if (backendValue.isNotEmpty) {
            selectedMileageRanges.add(backendValue);
          }
        }
        setState(() => _applyFilters());
      },
    );
  }

  // Fiyat Filtresi
  void _showPriceFilter(BuildContext context) {
    final Map<String, String> priceOptions = {
      '0-300k': 'vehicles.priceRange1'.tr(),
      '300k-500k': 'vehicles.priceRange2'.tr(),
      '500k-700k': 'vehicles.priceRange3'.tr(),
      '700k+': 'vehicles.priceRange4'.tr(),
    };

    final displayOptions = priceOptions.values.toList();
    final backendValues = priceOptions.keys.toList();

    final displaySelected = selectedPriceRanges.map((backendValue) {
      return priceOptions[backendValue] ?? backendValue;
    }).toSet();

    _showDropdownFilterWithMapping(
      context,
      title: 'vehicles.filterPrice'.tr(),
      displayOptions: displayOptions,
      backendValues: backendValues,
      selectedDisplayValues: displaySelected,
      onUpdate: (newDisplayValues) {
        selectedPriceRanges.clear();
        for (final displayValue in newDisplayValues) {
          final backendValue = priceOptions.entries
              .firstWhere(
                (entry) => entry.value == displayValue,
                orElse: () => const MapEntry('', ''),
              )
              .key;
          if (backendValue.isNotEmpty) {
            selectedPriceRanges.add(backendValue);
          }
        }
        setState(() => _applyFilters());
      },
    );
  }

  // Yıl Filtresi
  void _showYearFilter(BuildContext context) {
    final Map<String, String> yearOptions = {
      '2026': 'vehicles.yearRange0'.tr(),
      '2024-2025': 'vehicles.yearRange1'.tr(),
      '2020-2023': 'vehicles.yearRange2'.tr(),
      '2015-2019': 'vehicles.yearRange3'.tr(),
      '2015 öncesi': 'vehicles.yearRange4'.tr(),
    };

    final displayOptions = yearOptions.values.toList();
    final backendValues = yearOptions.keys.toList();

    final displaySelected = selectedYearRanges.map((backendValue) {
      return yearOptions[backendValue] ?? backendValue;
    }).toSet();

    _showDropdownFilterWithMapping(
      context,
      title: 'vehicles.filterYear'.tr(),
      displayOptions: displayOptions,
      backendValues: backendValues,
      selectedDisplayValues: displaySelected,
      onUpdate: (newDisplayValues) {
        selectedYearRanges.clear();
        for (final displayValue in newDisplayValues) {
          final backendValue = yearOptions.entries
              .firstWhere(
                (entry) => entry.value == displayValue,
                orElse: () => const MapEntry('', ''),
              )
              .key;
          if (backendValue.isNotEmpty) {
            selectedYearRanges.add(backendValue);
          }
        }
        setState(() => _applyFilters());
      },
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

  // Filtre Kaydetme Dialogu
  void _showSaveFilterDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    bool isButtonEnabled = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filtreyi Kaydet'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Filtre Adı',
                      hintText: 'Örn: Ucuz Sedanlar',
                    ),
                    onChanged: (value) {
                      setState(() {
                        isButtonEnabled = value.trim().isNotEmpty;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isButtonEnabled
                      ? () {
                          if (savedFilters.length >= 5) {
                            // Max limit uyarısı (opsiyonel, ama iyi olur)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'En fazla 5 filtre kaydedebilirsiniz.',
                                ),
                              ),
                            );
                            Navigator.pop(context);
                            return;
                          }
                          _saveFilter(controller.text.trim());
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _selectedSortOption == value;
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedSortOption = null;
          } else {
            _selectedSortOption = value;
          }
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.categoryColor.withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? widget.categoryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? widget.categoryColor : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class SavedFilter {
  final String name;
  final Set<String> fuelTypes;
  final Set<String> transmissions;
  final Set<String> mileageRanges;
  final Set<String> priceRanges;
  final Set<String> yearRanges;

  final String? sortOption;

  SavedFilter({
    required this.name,
    required this.fuelTypes,
    required this.transmissions,
    required this.mileageRanges,
    required this.priceRanges,
    required this.yearRanges,
    this.sortOption,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fuelTypes': fuelTypes.toList(),
      'transmissions': transmissions.toList(),
      'mileageRanges': mileageRanges.toList(),
      'priceRanges': priceRanges.toList(),
      'yearRanges': yearRanges.toList(),
      'sortOption': sortOption,
    };
  }

  factory SavedFilter.fromJson(Map<String, dynamic> json) {
    return SavedFilter(
      name: json['name'],
      fuelTypes: Set<String>.from(json['fuelTypes']),
      transmissions: Set<String>.from(json['transmissions']),
      mileageRanges: Set<String>.from(json['mileageRanges']),
      priceRanges: Set<String>.from(json['priceRanges']),
      yearRanges: Set<String>.from(json['yearRanges']),
      sortOption: json['sortOption'],
    );
  }
}
