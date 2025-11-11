import 'package:flutter/material.dart';
import 'vehicle_list_screen.dart';

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
    // Simülasyon araç markaları (telif riski olmayan isimler)
    final brands = [
      {
        'name': 'Alfio',
        'originalHint': 'İtalyan spor karakteri',
        'color': Colors.red,
        'icon': 'A',
        'imagePath': 'assets/images/car_brands/alfio.jpeg',
      },
      {
        'name': 'Audix',
        'originalHint': 'Alman lüks performansı',
        'color': Colors.grey[800]!,
        'icon': 'A',
        'imagePath': 'assets/images/car_brands/audix.jpeg',
      },
      {
        'name': 'BMV',
        'originalHint': 'Bavyera motoru',
        'color': Colors.blue[700]!,
        'icon': 'B',
        'imagePath': 'assets/images/car_brands/bmv.jpeg',
      },
      {
        'name': 'Chevro',
        'originalHint': 'Amerikan gücü',
        'color': Colors.amber[700]!,
        'icon': 'C',
        'imagePath': 'assets/images/car_brands/chevro.jpeg',
      },
      {
        'name': 'Fait Motors',
        'originalHint': 'İtalyan şıklığı',
        'color': Colors.red[600]!,
        'icon': 'F',
        'imagePath': 'assets/images/car_brands/fait.jpeg',
      },
      {
        'name': 'Forde',
        'originalHint': 'Amerikan klasiği',
        'color': Colors.blue[900]!,
        'icon': 'F',
        'imagePath': 'assets/images/car_brands/forde.jpeg',
      },
      {
        'name': 'Hyunday',
        'originalHint': 'Kore teknolojisi',
        'color': Colors.grey[700]!,
        'icon': 'H',
        'imagePath': 'assets/images/car_brands/hyunday.jpeg',
      },
      {
        'name': 'Hondia',
        'originalHint': 'Japon güvenilirliği',
        'color': Colors.red[700]!,
        'icon': 'H',
        'imagePath': 'assets/images/car_brands/hondia.jpeg',
      },
      {
        'name': 'Kio',
        'originalHint': 'Kore tasarımı',
        'color': Colors.red[800]!,
        'icon': 'K',
        'imagePath': 'assets/images/car_brands/kio.jpeg',
      },
      {
        'name': 'Mercedez',
        'originalHint': 'Alman lüksü',
        'color': Colors.grey[600]!,
        'icon': 'M',
        'imagePath': 'assets/images/car_brands/mercedez.jpeg',
      },
      {
        'name': 'Mazdo',
        'originalHint': 'Japon dinamizmi',
        'color': Colors.red[900]!,
        'icon': 'M',
        'imagePath': 'assets/images/car_brands/mazdo.jpeg',
      },
      {
        'name': 'Nissano',
        'originalHint': 'Japon inovasyonu',
        'color': Colors.grey[800]!,
        'icon': 'N',
        'imagePath': 'assets/images/car_brands/nissano.jpeg',
      },
      {
        'name': 'Opex',
        'originalHint': 'Alman pratikliği',
        'color': Colors.yellow[700]!,
        'icon': 'O',
        'imagePath': 'assets/images/car_brands/opex.jpeg',
      },
      {
        'name': 'Pejo',
        'originalHint': 'Fransız zarafeti',
        'color': Colors.blue[800]!,
        'icon': 'P',
        'imagePath': 'assets/images/car_brands/pejo.jpeg',
      },
      {
        'name': 'Renol',
        'originalHint': 'Fransız inovasyonu',
        'color': Colors.yellow[800]!,
        'icon': 'R',
        'imagePath': 'assets/images/car_brands/renol.jpeg',
      },
      {
        'name': 'Seato',
        'originalHint': 'İspanyol tutkusu',
        'color': Colors.red[700]!,
        'icon': 'S',
        'imagePath': 'assets/images/car_brands/seato.jpeg',
      },
      {
        'name': 'Škodai',
        'originalHint': 'Çek değeri',
        'color': Colors.green[700]!,
        'icon': 'Š',
        'imagePath': 'assets/images/car_brands/skodai.jpeg',
      },
      {
        'name': 'Toyoto',
        'originalHint': 'Japon mükemmelliği',
        'color': Colors.red[600]!,
        'icon': 'T',
        'imagePath': 'assets/images/car_brands/toyoto.jpeg',
      },
      {
        'name': 'Volksvan',
        'originalHint': 'Halkın arabası',
        'color': Colors.blue[700]!,
        'icon': 'V',
        'imagePath': 'assets/images/car_brands/volksvan.jpeg',
      },
      {
        'name': 'Volvy',
        'originalHint': 'İsveç güvenliği',
        'color': Colors.blue[900]!,
        'icon': 'V',
        'imagePath': 'assets/images/car_brands/volvy.jpeg',
      },
    ];

    // Alfabetik sırala
    brands.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Marka Seçin'),
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
                    '$categoryName kategorisinde hangi markayı tercih edersiniz?',
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
                  hint: brand['originalHint'] as String,
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VehicleListScreen(
                  categoryName: '$categoryName - Tüm Modeller',
                  categoryColor: categoryColor,
                  brandName: null, // null = tüm markalar
                ),
              ),
            );
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
                        'Tüm Modeller',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tüm markaların araçlarını görüntüle',
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
          onTap: () {
            // Seçilen markaya göre araç listesi sayfasına git
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VehicleListScreen(
                  categoryName: '$categoryName - $name',
                  categoryColor: categoryColor,
                  brandName: name, // Spesifik marka
                ),
              ),
            );
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

