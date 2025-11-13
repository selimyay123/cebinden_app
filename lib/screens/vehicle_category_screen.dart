import 'package:flutter/material.dart';
import 'vehicle_list_screen.dart';
import 'brand_selection_screen.dart';

class VehicleCategoryScreen extends StatelessWidget {
  const VehicleCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Araç kategorileri
    final categories = [
      {
        'title': 'Otomobil',
        'icon': Icons.directions_car,
        'color': Colors.blue,
        'description': 'Sedan, hatchback ve coupe modeller',
      },
    //   {
    //     'title': 'Arazi, SUV & Pickup',
    //     'icon': Icons.terrain,
    //     'color': Colors.green,
    //     'description': 'Off-road ve çok amaçlı araçlar',
    //   },
      {
        'title': 'Elektrikli Araçlar',
        'icon': Icons.electric_car,
        'color': Colors.teal,
        'description': 'Çevre dostu elektrikli modeller',
      },
      {
        'title': 'Ticari Araçlar',
        'icon': Icons.local_shipping,
        'color': Colors.orange,
        'description': 'Kamyonet, minibüs ve hafif ticari',
      },
      {
        'title': 'Hasarlı Araçlar',
        'icon': Icons.build,
        'color': Colors.red,
        'description': 'Tamir gerektiren araçlar',
      },
      {
        'title': 'Klasik Araçlar',
        'icon': Icons.stars,
        'color': Colors.purple,
        'description': 'Koleksiyon değeri olan araçlar',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Araç Kategorisi Seçin'),
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
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String description,
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
            // Otomobil kategorisi için marka seçimi, diğerleri için direkt liste
            if (title == 'Otomobil') {
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

