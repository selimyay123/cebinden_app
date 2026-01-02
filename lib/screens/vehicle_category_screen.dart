import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import 'vehicle_list_screen.dart';
import 'brand_selection_screen.dart';
import 'main_screen.dart';

class VehicleCategoryScreen extends StatelessWidget {
  const VehicleCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder ile dil değişikliklerini dinle
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        // Araç kategorileri - dil değiştiğinde yeniden oluşturulur
        final categories = [
          {
            'title': 'vehicles.categoryAuto'.tr(),
            'icon': Icons.directions_car,
            'color': Colors.blue,
            'description': 'vehicles.categoryAutoDesc'.tr(),
            'key': 'auto', // Dil bağımsız key
          },
          {
            'title': 'vehicles.categoryElectric'.tr(),
            'icon': Icons.electric_car,
            'color': Colors.teal,
            'description': 'vehicles.categoryElectricDesc'.tr(),
            'key': 'electric',
          },
          {
            'title': 'vehicles.categoryCommercial'.tr(),
            'icon': Icons.local_shipping,
            'color': Colors.orange,
            'description': 'vehicles.categoryCommercialDesc'.tr(),
            'key': 'commercial',
          },
          {
            'title': 'vehicles.categoryDamaged'.tr(),
            'icon': Icons.build,
            'color': Colors.red,
            'description': 'vehicles.categoryDamagedDesc'.tr(),
            'key': 'damaged',
          },
          {
            'title': 'vehicles.categoryClassic'.tr(),
            'icon': Icons.stars,
            'color': Colors.purple,
            'description': 'vehicles.categoryClassicDesc'.tr(),
            'key': 'classic',
          },
        ];

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text('vehicles.selectCategory'.tr()),
            actions: [

            ],
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryCard(
                context,
                title: category['title'] as String,
                icon: category['icon'] as IconData,
                color: category['color'] as Color,
                description: category['description'] as String,
                categoryKey: category['key'] as String,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required String categoryKey,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: () async {
            // isi için marka seçimi, diğerleri için direkt liste
            if (categoryKey == 'auto') {
              final purchased = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BrandSelectionScreen(
                    categoryName: title,
                    categoryColor: color,
                  ),
                ),
              );
              
              // Eğer satın alma başarılıysa, home screen'e bildir
              if (purchased == true && context.mounted) {
                Navigator.pop(context, true);
              }
            } else {
              // Diğer kategoriler için direkt araç listesi
              final purchased = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VehicleListScreen(
                    categoryName: title,
                    categoryColor: color,
                    brandName: null, // Bu kategorilerde tüm markalar
                  ),
                ),
              );
              
              // Eğer satın alma başarılıysa, home screen'e bildir
              if (purchased == true && context.mounted) {
                Navigator.pop(context, true);
              }
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Kategori İkonu
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Kategori Bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Ok İkonu
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

