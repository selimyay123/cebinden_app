import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/market_refresh_service.dart';
import '../models/vehicle_model.dart';
import 'vehicle_detail_screen.dart';

class VehicleListScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;
  final String? brandName; // null = tüm markalar

  const VehicleListScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    this.brandName,
  });

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final MarketRefreshService _marketService = MarketRefreshService();
  
  List<Vehicle> allVehicles = []; // Tüm araçlar
  List<Vehicle> filteredVehicles = []; // Filtrelenmiş araçlar
  
  // Filtre durumları
  Set<String> selectedFuelTypes = {};
  Set<String> selectedTransmissions = {};
  String? selectedMileageRange;
  String? selectedPriceRange;
  String? selectedYearRange;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }
  
  // Araçları market servisinden yükle
  void _loadVehicles() {
    setState(() {
      allVehicles = _marketService.getActiveListings(brand: widget.brandName);
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
                        'Yakıt Tipi',
                        selectedFuelTypes.isNotEmpty,
                        selectedFuelTypes.length,
                        () => _showFuelTypeFilter(context),
                      ),
                      const SizedBox(width: 8),
                      
                      // Vites
                      _buildCategoryFilter(
                        'Vites',
                        selectedTransmissions.isNotEmpty,
                        selectedTransmissions.length,
                        () => _showTransmissionFilter(context),
                      ),
                      const SizedBox(width: 8),
                      
                      // Kilometre
                      _buildCategoryFilter(
                        'Kilometre',
                        selectedMileageRange != null,
                        selectedMileageRange != null ? 1 : 0,
                        () => _showMileageFilter(context),
                      ),
                      const SizedBox(width: 8),
                      
                      // Fiyat
                      _buildCategoryFilter(
                        'Fiyat',
                        selectedPriceRange != null,
                        selectedPriceRange != null ? 1 : 0,
                        () => _showPriceFilter(context),
                      ),
                      const SizedBox(width: 8),
                      
                      // Yıl
                      _buildCategoryFilter(
                        'Yıl',
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
                                  'Temizle',
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
  
  // Genel Dropdown Filter (Multi-select)
  void _showDropdownFilter(
    BuildContext context, {
    required String title,
    required List<String> options,
    required Set<String> selectedValues,
    required VoidCallback onUpdate,
  }) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              return SizedBox(
                width: 250,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Başlık ve Temizle Butonu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (selectedValues.isNotEmpty)
                          InkWell(
                            onTap: () {
                              setMenuState(() => selectedValues.clear());
                              onUpdate();
                            },
                            child: Icon(Icons.clear, size: 20, color: Colors.red[700]),
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Seçenekler
                    ...options.map((option) => InkWell(
                      onTap: () {
                        setMenuState(() {
                          if (selectedValues.contains(option)) {
                            selectedValues.remove(option);
                          } else {
                            selectedValues.add(option);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (selectedValues.contains(option))
                              const Icon(Icons.check, color: Colors.green, size: 20),
                          ],
                        ),
                      ),
                    )).toList(),
                    const SizedBox(height: 12),
                    // Uygula Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          onUpdate();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.categoryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Uygula', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              return SizedBox(
                width: 250,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Başlık ve Temizle Butonu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (selectedValue != null)
                          InkWell(
                            onTap: () {
                              setMenuState(() => selectedValue = null);
                              onUpdate(null);
                            },
                            child: Icon(Icons.clear, size: 20, color: Colors.red[700]),
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Seçenekler
                    ...options.entries.map((entry) => InkWell(
                      onTap: () {
                        setMenuState(() {
                          selectedValue = selectedValue == entry.key ? null : entry.key;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (selectedValue == entry.key)
                              const Icon(Icons.check, color: Colors.green, size: 20),
                          ],
                        ),
                      ),
                    )).toList(),
                    const SizedBox(height: 12),
                    // Uygula Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          onUpdate(selectedValue);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.categoryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Uygula', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Yakıt Tipi Filtresi
  void _showFuelTypeFilter(BuildContext context) {
    _showDropdownFilter(
      context,
      title: 'vehicles.fuelType'.tr(),
      options: ['Benzin', 'Dizel', 'Hybrid', 'Elektrik'],
      selectedValues: selectedFuelTypes,
      onUpdate: () => setState(() => _applyFilters()),
    );
  }

  // Vites Filtresi
  void _showTransmissionFilter(BuildContext context) {
    _showDropdownFilter(
      context,
      title: 'Vites',
      options: ['Manuel', 'Otomatik'],
      selectedValues: selectedTransmissions,
      onUpdate: () => setState(() => _applyFilters()),
    );
  }
  
  // Kilometre Filtresi
  void _showMileageFilter(BuildContext context) {
    _showSingleSelectFilter(
      context,
      title: 'Kilometre',
      options: {
        '0-50k': '0-50k km',
        '50k-100k': '50k-100k km',
        '100k-150k': '100k-150k km',
        '150k+': '150k+ km',
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
      title: 'Fiyat',
      options: {
        '0-300k': '0-300k TL',
        '300k-500k': '300k-500k TL',
        '500k-700k': '500k-700k TL',
        '700k+': '700k+ TL',
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
      title: 'vehicles.modelYear'.tr(),
      options: {
        '2024': '2024',
        '2020-2023': '2020-2023',
        '2015-2019': '2015-2019',
        '2015 öncesi': '2015 öncesi',
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
}

