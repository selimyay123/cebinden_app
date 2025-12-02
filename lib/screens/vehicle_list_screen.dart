import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/market_refresh_service.dart';
import '../models/vehicle_model.dart';
import 'vehicle_detail_screen.dart';

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
  String? selectedMileageRange;
  String? selectedPriceRange;
  String? selectedYearRange;
  String? _selectedSortOption; // 'price_asc', 'price_desc'
  
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

  @override
  void initState() {
    super.initState();
    _loadVehicles();
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
        if (selectedFuelTypes.isNotEmpty && !selectedFuelTypes.contains(vehicle.fuelType)) {
          return false;
        }
        
        // Vites filtresi
        if (selectedTransmissions.isNotEmpty && !selectedTransmissions.contains(vehicle.transmission)) {
          return false;
        }
        
        // Kilometre filtresi
        if (selectedMileageRange != null) {
          if (selectedMileageRange == '0-50k' && vehicle.mileage > 50000) return false;
          if (selectedMileageRange == '50k-100k' && (vehicle.mileage < 50000 || vehicle.mileage > 100000)) return false;
          if (selectedMileageRange == '100k-150k' && (vehicle.mileage < 100000 || vehicle.mileage > 150000)) return false;
          if (selectedMileageRange == '150k+' && vehicle.mileage < 150000) return false;
        }
        
        // Fiyat filtresi
        if (selectedPriceRange != null) {
          if (selectedPriceRange == '0-300k' && vehicle.price > 300000) return false;
          if (selectedPriceRange == '300k-500k' && (vehicle.price < 300000 || vehicle.price > 500000)) return false;
          if (selectedPriceRange == '500k-700k' && (vehicle.price < 500000 || vehicle.price > 700000)) return false;
          if (selectedPriceRange == '700k+' && vehicle.price < 700000) return false;
        }
        
        // Yıl filtresi
        if (selectedYearRange != null) {
          if (selectedYearRange == '2024' && vehicle.year != 2024) return false;
          if (selectedYearRange == '2020-2023' && (vehicle.year < 2020 || vehicle.year > 2023)) return false;
          if (selectedYearRange == '2015-2019' && (vehicle.year < 2015 || vehicle.year > 2019)) return false;
          if (selectedYearRange == '2015 öncesi' && vehicle.year >= 2015) return false;
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
      selectedMileageRange = null;
      selectedPriceRange = null;
      selectedYearRange = null;
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: widget.categoryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filtreler (Üstte sabit)
          Container(
            color: Colors.white,
            child: Column(
              children: [
                // Ana Filtre Kategorileri
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        selectedMileageRange != null,
                        selectedMileageRange != null ? 1 : 0,
                        () => _showMileageFilter(context),
                      ),
                      const SizedBox(width: 8),
                      
                      // Fiyat
                      _buildCategoryFilter(
                        'vehicles.filterPrice'.tr(),
                        selectedPriceRange != null,
                        selectedPriceRange != null ? 1 : 0,
                        () => _showPriceFilter(context),
                      ),
                      const SizedBox(width: 8),
                      
                      // Yıl
                      _buildCategoryFilter(
                        'vehicles.filterYear'.tr(),
                        selectedYearRange != null,
                        selectedYearRange != null ? 1 : 0,
                        () => _showYearFilter(context),
                      ),
                      
                      // Temizle Butonu
                      if (selectedFuelTypes.isNotEmpty || 
                          selectedTransmissions.isNotEmpty || 
                          selectedMileageRange != null || 
                          selectedPriceRange != null || 
                          selectedYearRange != null) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: _clearFilters,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.clear, size: 16, color: Colors.red[700]),
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
                      ],
                    ],
                  ),
                ),
                
                // Sonuç Sayısı Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: widget.categoryColor.withOpacity(0.1),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
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
                    'Sırala:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildSortChip(
                    'Fiyat: Düşükten Yükseğe',
                    'price_asc',
                  ),
                  const SizedBox(width: 8),
                  _buildSortChip(
                    'Fiyat: Yüksekten Düşüğe',
                    'price_desc',
                  ),
                ],
              ),
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
    );
      },
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 140,
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
      child: InkWell(
        onTap: () async {
          // Araç detayına git ve satın alma sonucunu bekle
          final purchased = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VehicleDetailScreen(vehicle: vehicle),
            ),
          );
          
          // Listeyi yenile (Ekspertiz durumu değişmiş olabilir)
          if (context.mounted) {
            _loadVehicles();
            _applyFilters();
          }
          
          // Eğer satın alma başarılıysa, bir önceki sayfaya bildir
          if (purchased == true && context.mounted) {
            Navigator.pop(context, true);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Araç Resmi (Sol tarafta)
            Container(
              width: 120,
              decoration: BoxDecoration(
                color: widget.categoryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 50,
                      color: widget.categoryColor.withOpacity(0.6),
                    ),
                    const SizedBox(height: 4),
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
                            vehicle.fullName,
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
                            color: widget.categoryColor.withOpacity(0.1),
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
                        _buildCompactFeature(Icons.speed, '${_formatNumber(vehicle.mileage)} km'),
                        const SizedBox(width: 12),
                        _buildCompactFeature(Icons.local_gas_station, vehicle.fuelType),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
  
  // Kategori Filtre Butonu
  Widget _buildCategoryFilter(String label, bool hasSelection, int count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: hasSelection ? widget.categoryColor.withOpacity(0.1) : Colors.grey[100],
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
                        color: widget.categoryColor.withOpacity(0.1),
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
                          final isSelected = tempSelectedValues.contains(displayOption);
                          
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
                                    ? widget.categoryColor.withOpacity(0.1)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  setDialogState(() => tempSelectedValues.clear());
                                  onUpdate({});
                                  Navigator.pop(dialogContext);
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                        color: widget.categoryColor.withOpacity(0.1),
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
                                    ? widget.categoryColor.withOpacity(0.1)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
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

  // Genel Dropdown Filter (Single-select)
  void _showSingleSelectFilter(
    BuildContext context, {
    required String title,
    required Map<String, String> options,
    required String? selectedValue,
    required Function(String?) onUpdate,
  }) {
    String? tempSelectedValue = selectedValue;
    
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
                        color: widget.categoryColor.withOpacity(0.1),
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
                          if (tempSelectedValue != null)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: widget.categoryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
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
                          final entry = options.entries.elementAt(index);
                          final isSelected = tempSelectedValue == entry.key;
                          
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                tempSelectedValue = isSelected ? null : entry.key;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? widget.categoryColor.withOpacity(0.1)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.value,
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
                          if (tempSelectedValue != null)
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setDialogState(() => tempSelectedValue = null);
                                  onUpdate(null);
                                  Navigator.pop(dialogContext);
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                          if (tempSelectedValue != null)
                            const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                onUpdate(tempSelectedValue);
                                Navigator.pop(dialogContext);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.categoryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
    final displayOptions = _fuelTypeMapping.keys.map((key) => _fuelTypeMapping[key]!.tr()).toList();
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
    final displayOptions = _transmissionMapping.keys.map((key) => _transmissionMapping[key]!.tr()).toList();
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
    _showSingleSelectFilter(
      context,
      title: 'vehicles.filterMileage'.tr(),
      options: {
        '0-50k': 'vehicles.mileageRange1'.tr(),
        '50k-100k': 'vehicles.mileageRange2'.tr(),
        '100k-150k': 'vehicles.mileageRange3'.tr(),
        '150k+': 'vehicles.mileageRange4'.tr(),
      },
      selectedValue: selectedMileageRange,
      onUpdate: (value) => setState(() {
        selectedMileageRange = value;
        _applyFilters();
      }),
    );
  }
  
  // Fiyat Filtresi
  void _showPriceFilter(BuildContext context) {
    _showSingleSelectFilter(
      context,
      title: 'vehicles.filterPrice'.tr(),
      options: {
        '0-300k': 'vehicles.priceRange1'.tr(),
        '300k-500k': 'vehicles.priceRange2'.tr(),
        '500k-700k': 'vehicles.priceRange3'.tr(),
        '700k+': 'vehicles.priceRange4'.tr(),
      },
      selectedValue: selectedPriceRange,
      onUpdate: (value) => setState(() {
        selectedPriceRange = value;
        _applyFilters();
      }),
    );
  }
  
  // Yıl Filtresi
  void _showYearFilter(BuildContext context) {
    _showSingleSelectFilter(
      context,
      title: 'vehicles.filterYear'.tr(),
      options: {
        '2024': 'vehicles.yearRange1'.tr(),
        '2020-2023': 'vehicles.yearRange2'.tr(),
        '2015-2019': 'vehicles.yearRange3'.tr(),
        '2015 öncesi': 'vehicles.yearRange4'.tr(),
      },
      selectedValue: selectedYearRange,
      onUpdate: (value) => setState(() {
        selectedYearRange = value;
        _applyFilters();
      }),
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
          color: isSelected ? widget.categoryColor.withOpacity(0.1) : Colors.grey[100],
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

