import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import 'vehicle_list_screen.dart';
import 'model_selection_screen.dart';

class BrandSelectionScreen extends StatelessWidget {
  final String categoryName;
  final Color categoryColor;

  const BrandSelectionScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder ile dil değişikliklerini dinle
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        // Simülasyon araç markaları (telif riski olmayan isimler)
        final brands = [
      {
        'name': 'Audira', // Audi
        'originalHint': 'Alman lüks performansı',
        'color': Colors.grey[800]!,
        'icon': 'A',
        'imagePath': 'assets/images/car_brands/audix.jpeg',
      },
      {
        'name': 'Bavora', // BMW
        'originalHint': 'Bavyera motoru',
        'color': Colors.blue[700]!,
        'icon': 'B',
        'imagePath': 'assets/images/car_brands/bmv.jpeg',
      },
      // {
      //   'name': 'Citronix', // Citroen
      //   'originalHint': 'Fransız konforu',
      //   'color': Colors.red[400]!,
      //   'icon': 'C',
      //   'imagePath': 'assets/images/car_brands/alfio.jpeg',
      // },
      {
        'name': 'Fialto', // Fiat
        'originalHint': 'İtalyan pratikliği',
        'color': Colors.red[600]!,
        'icon': 'F',
        'imagePath': 'assets/images/car_brands/fait.jpeg',
      }, 
      {
        'name': 'Fortran', // Ford
        'originalHint': 'Amerikan klasiği',
        'color': Colors.blue[900]!,
        'icon': 'F',
        'imagePath': 'assets/images/car_brands/forde.jpeg',
      },
      {
        'name': 'Hundar', // Hyundai
        'originalHint': 'Kore teknolojisi',
        'color': Colors.grey[700]!,
        'icon': 'H',
        'imagePath': 'assets/images/car_brands/hyunday.jpeg',
      },
      {
        'name': 'Hanto',
        'originalHint': 'Japon güvenilirliği',
        'color': Colors.red[700]!,
        'icon': 'H',
        'imagePath': 'assets/images/car_brands/hondia.jpeg',
      },
      {
        'name': 'Mercurion', // Mercedes
        'originalHint': 'Alman lüksü',
        'color': Colors.grey[600]!,
        'icon': 'M',
        'imagePath': 'assets/images/car_brands/mercedez.jpeg',
      },
      {
        'name': 'Oplon', // Opel
        'originalHint': 'Alman pratikliği',
        'color': Colors.yellow[700]!,
        'icon': 'O',
        'imagePath': 'assets/images/car_brands/opex.jpeg',
      },
      // {
      //   'name': 'Peugot', // Peugeot
      //   'originalHint': 'Fransız zarafeti',
      //   'color': Colors.blue[800]!,
      //   'icon': 'P',
      //   'imagePath': 'assets/images/car_brands/pejo.jpeg',
      // },
      {
        'name': 'Renauva', // Renault
        'originalHint': 'Fransız inovasyonu',
        'color': Colors.yellow[800]!,
        'icon': 'R',
        'imagePath': 'assets/images/car_brands/renol.jpeg',
      },
      // {
      //   'name': 'Skodra', // Škoda
      //   'originalHint': 'Çek değeri',
      //   'color': Colors.green[700]!,
      //   'icon': 'Š',
      //   'imagePath': 'assets/images/car_brands/skodai.jpeg',
      // },
      {
        'name': 'Koyoro', // Toyota
        'originalHint': 'Japon mükemmelliği',
        'color': Colors.red[600]!,
        'icon': 'T',
        'imagePath': 'assets/images/car_brands/koyoro.jpeg',
      },
      {
        'name': 'Volkstar', // Volkswagen
        'originalHint': 'Halkın arabası',
        'color': Colors.blue[700]!,
        'icon': 'V',
        'imagePath': 'assets/images/car_brands/volksvan.jpeg',
      },
    ];

    // Alfabetik sırala
    brands.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('vehicles.selectBrand'.tr()),
        backgroundColor: categoryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Bilgilendirme Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: categoryColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: categoryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${'vehicles.categoryInfoAuto'.tr()} $categoryName',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Marka Listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: brands.length + 1, // +1 for "Tüm Modeller"
              itemBuilder: (context, index) {
                // İlk item "Tüm Modeller"
                if (index == 0) {
                  return _buildAllBrandsCard(context);
                }
                
                // Diğer markalar
                final brand = brands[index - 1];
                return _buildBrandCard(
                  context,
                  name: brand['name'] as String,
                  hint: 'brands.hints.${brand['name']}'.tr(),
                  color: brand['color'] as Color,
                  icon: brand['icon'] as String,
                  imagePath: brand['imagePath'] as String?,
                );
              },
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildAllBrandsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: categoryColor,
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        shadowColor: categoryColor.withOpacity(0.3),
        child: InkWell(
          onTap: () async {
            final purchased = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VehicleListScreen(
                  categoryName: '$categoryName - ${'vehicles.allModels'.tr()}',
                  categoryColor: categoryColor,
                  brandName: null, // null = tüm markalar
                  modelName: null, // null = tüm modeller
                ),
              ),
            );
            
            // Eğer satın alma başarılıysa, bir önceki sayfaya bildir
            if (purchased == true && context.mounted) {
              Navigator.pop(context, true);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.apps,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'vehicles.allModels'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'vehicles.allModelsDesc'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandCard(
    BuildContext context, {
    required String name,
    required String hint,
    required Color color,
    required String icon,
    String? imagePath,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        child: InkWell(
          onTap: () async {
            // Seçilen markaya göre MODEL SEÇİM sayfasına git
            final purchased = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModelSelectionScreen(
                  categoryName: categoryName,
                  categoryColor: categoryColor,
                  brandName: name,
                ),
              ),
            );
            
            // Eğer satın alma başarılıysa, bir önceki sayfaya bildir
            if (purchased == true && context.mounted) {
              Navigator.pop(context, true);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Marka Logosu
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            imagePath,
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Resim yüklenemezse harf göster
                              return Center(
                                child: Text(
                                  icon,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            icon,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                
                // Marka Bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 13,
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
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

