import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/market_refresh_service.dart';
import 'vehicle_list_screen.dart';

class ModelSelectionScreen extends StatelessWidget {
  final String categoryName;
  final Color categoryColor;
  final String brandName;

  const ModelSelectionScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    required this.brandName,
  });

  @override
  Widget build(BuildContext context) {
    // Markaya göre modelleri al
    final marketService = MarketRefreshService();
    final modelsByBrand = marketService.getModelsByBrand();
    final models = modelsByBrand[brandName] ?? [];

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text('Marka Seçiniz'),
            // title: Text('vehicles.selectModel'.tr()),
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
                        currentLanguage == 'tr'
                            ? '$brandName markasının hangi modelini tercih edersiniz?'
                            : 'Which $brandName model do you prefer?',
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
              
              // Model Listesi
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: models.length + 1, // +1 for "Tüm Modeller"
                  itemBuilder: (context, index) {
                    // İlk item "Tüm Modeller"
                    if (index == 0) {
                      return _buildAllModelsCard(context, currentLanguage);
                    }
                    
                    // Diğer modeller
                    final model = models[index - 1];
                    return _buildModelCard(
                      context,
                      modelName: model,
                      currentLanguage: currentLanguage,
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

  Widget _buildAllModelsCard(BuildContext context, String currentLanguage) {
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
                  categoryName: '$categoryName - $brandName - ${'vehicles.allModels'.tr()}',
                  categoryColor: categoryColor,
                  brandName: brandName,
                  modelName: null, // null = tüm modeller
                ),
              ),
            );
            
            // Eğer satın alma başarılıysa, geriye dön
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
                  child: const Icon(
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
                        currentLanguage == 'tr'
                            ? '$brandName markasının tüm modellerini görüntüle'
                            : 'View all $brandName models',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                const Icon(
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

  Widget _buildModelCard(
    BuildContext context, {
    required String modelName,
    required String currentLanguage,
  }) {
    // Model ikonunu belirle (ilk harf)
    final modelIcon = modelName[0].toUpperCase();
    
    // Model açıklaması (isteğe bağlı)
    final modelDescription = _getModelDescription(modelName, currentLanguage);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        child: InkWell(
          onTap: () async {
            // Seçilen modele göre araç listesi sayfasına git
            final purchased = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VehicleListScreen(
                  categoryName: '$categoryName - $brandName - $modelName',
                  categoryColor: categoryColor,
                  brandName: brandName,
                  modelName: modelName,
                ),
              ),
            );
            
            // Eğer satın alma başarılıysa, geriye dön
            if (purchased == true && context.mounted) {
              Navigator.pop(context, true);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Model İkonu
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: categoryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      modelIcon,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Model Bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modelName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (modelDescription != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          modelDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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

  String? _getModelDescription(String modelName, String currentLanguage) {
    // Renauva modelleri için açıklamalar
    if (brandName == 'Renauva') {
      switch (modelName) {
        case 'Slim':
          return currentLanguage == 'tr'
              ? 'Modern Hatchback, genç ve dinamik'
              : 'Modern Hatchback, young and dynamic';
        case 'Magna':
          return currentLanguage == 'tr'
              ? 'Premium Orta Sınıf, konforlu'
              : 'Premium Mid-Size, comfortable';
        case 'Flow':
          return currentLanguage == 'tr'
              ? 'Geniş Sedan, uzun yol konforu'
              : 'Spacious Sedan, long-distance comfort';
        case 'Signa':
          return currentLanguage == 'tr'
              ? 'Ekonomik Sedan, pratik kullanım'
              : 'Economic Sedan, practical use';
        case 'Tallion':
          return currentLanguage == 'tr'
              ? 'Yeni Nesil, modern teknoloji'
              : 'New Generation, modern technology';
      }
    }
    // Voltswagen modelleri için açıklamalar
    else if (brandName == 'Voltswagen') {
      switch (modelName) {
        case 'Paso':
          return currentLanguage == 'tr'
              ? 'Premium Segment, lüks ve güç'
              : 'Premium Segment, luxury and power';
        case 'Tenis':
          return currentLanguage == 'tr'
              ? 'Kompakt Premium, yüksek talep'
              : 'Compact Premium, high demand';
        case 'Colo':
          return currentLanguage == 'tr'
              ? 'Premium Küçük, kaliteli ve pratik'
              : 'Premium Small, quality and practical';
        case 'Jago':
          return currentLanguage == 'tr'
              ? 'Geniş Sedan, aile dostu'
              : 'Spacious Sedan, family-friendly';
      }
    }
    // Fialto modelleri için açıklamalar
    else if (brandName == 'Fialto') {
      switch (modelName) {
        case 'Agna':
          return currentLanguage == 'tr'
              ? 'Hacim Kralı, çok satan model'
              : 'Volume King, best-selling model';
        case 'Lagua':
          return currentLanguage == 'tr'
              ? 'Ekonomik Sedan, basit ve sağlam'
              : 'Economic Sedan, simple and solid';
        case 'Zorno':
          return currentLanguage == 'tr'
              ? 'Kompakt Hatchback, şehir aracı'
              : 'Compact Hatchback, city car';
      }
    }
    // Opexel modelleri için açıklamalar
    else if (brandName == 'Opexel') {
      switch (modelName) {
        case 'Tasra':
          return currentLanguage == 'tr'
              ? 'Güvenilir Alman kalitesi, popüler'
              : 'Reliable German quality, popular';
        case 'Lorisa':
          return currentLanguage == 'tr'
              ? 'Kompakt, ekonomik ve güvenilir'
              : 'Compact, economic and reliable';
        case 'Mornitia':
          return currentLanguage == 'tr'
              ? 'Premium Segment, lüks donanım'
              : 'Premium Segment, luxury equipment';
      }
    }
    // Bavora modelleri için açıklamalar
    else if (brandName == 'Bavora') {
      switch (modelName) {
        case 'C Serisi':
          return currentLanguage == 'tr'
              ? 'Popüler Premium, en çok satan'
              : 'Popular Premium, best-selling';
        case 'E Serisi':
          return currentLanguage == 'tr'
              ? 'Lüks Segment, en prestijli'
              : 'Luxury Segment, most prestigious';
        case 'A Serisi':
          return currentLanguage == 'tr'
              ? 'Kompakt Premium, genç ve dinamik'
              : 'Compact Premium, young and dynamic';
        case 'D Serisi':
          return currentLanguage == 'tr'
              ? 'Sportif Coupe, şık ve güçlü'
              : 'Sporty Coupe, elegant and powerful';
      }
    }
    // Fortran modelleri için açıklamalar
    else if (brandName == 'Fortran') {
      switch (modelName) {
        case 'Odak':
          return currentLanguage == 'tr'
              ? 'C Segment lideri, sürüş keyfi'
              : 'C Segment leader, driving pleasure';
        case 'Vista':
          return currentLanguage == 'tr'
              ? 'Kompakt, ekonomik, dinamik'
              : 'Compact, economic, dynamic';
        case 'Avger':
          return currentLanguage == 'tr'
              ? 'Güçlü Pick-up, 4x4 arazi'
              : 'Powerful Pick-up, 4x4 off-road';
        case 'Tupa':
          return currentLanguage == 'tr'
              ? 'SUV konfor, geniş ve modern'
              : 'SUV comfort, spacious and modern';
      }
    }
    // Mercurion modelleri için açıklamalar
    else if (brandName == 'Mercurion') {
      switch (modelName) {
        case '3 Serisi':
          return currentLanguage == 'tr'
              ? 'Premium konfor, klasik lüks'
              : 'Premium comfort, classic luxury';
        case '5 Serisi':
          return currentLanguage == 'tr'
              ? 'Üst düzey lüks, makam aracı'
              : 'Top-level luxury, executive car';
        case '1 Serisi':
          return currentLanguage == 'tr'
              ? 'Kompakt premium, MBUX teknoloji'
              : 'Compact premium, MBUX technology';
        case 'GJE':
          return currentLanguage == 'tr'
              ? '4 Kapı Coupe, sportif şık'
              : '4-Door Coupe, sporty elegant';
        case '8 Serisi':
          return currentLanguage == 'tr'
              ? 'Efsane arazi, ultra lüks'
              : 'Legendary off-road, ultra luxury';
      }
    }
    // Hyundaro modelleri için açıklamalar
    else if (brandName == 'Hyundaro') {
      switch (modelName) {
        case 'A10':
          return currentLanguage == 'tr'
              ? 'Güvenilir, ekonomik hatchback'
              : 'Reliable, economic hatchback';
        case 'Tecent Red':
          return currentLanguage == 'tr'
              ? 'Güçlü dizel, ekonomik sedan'
              : 'Powerful diesel, economic sedan';
        case 'Tecent White':
          return currentLanguage == 'tr'
              ? 'Basit sağlam, ucuz onarım'
              : 'Simple solid, cheap repair';
        case 'A20':
          return currentLanguage == 'tr'
              ? 'Dengeli C segment, zengin donanım'
              : 'Balanced C segment, rich equipment';
        case 'Kascon':
          return currentLanguage == 'tr'
              ? 'Modern SUV, hibrit teknoloji'
              : 'Modern SUV, hybrid technology';
      }
    }
    // Toyoto modelleri için açıklamalar
    else if (brandName == 'Toyoto') {
      switch (modelName) {
        case 'Airoko':
          return currentLanguage == 'tr'
              ? 'Efsane güvenilirlik, hibrit lider'
              : 'Legendary reliability, hybrid leader';
        case 'Lotus':
          return currentLanguage == 'tr'
              ? 'Güvenilir hatchback, hibrit mevcut'
              : 'Reliable hatchback, hybrid available';
        case 'Karma':
          return currentLanguage == 'tr'
              ? 'Kompakt pratik, hibrit teknoloji'
              : 'Compact practical, hybrid technology';
      }
    }
    // Audira modelleri için açıklamalar
    else if (brandName == 'Audira') {
      switch (modelName) {
        case 'B3':
          return currentLanguage == 'tr'
              ? 'Premium kompakt, teknoloji lideri'
              : 'Premium compact, technology leader';
        case 'B4':
          return currentLanguage == 'tr'
              ? 'D segment konforu, prestij'
              : 'D segment comfort, prestige';
        case 'B6':
          return currentLanguage == 'tr'
              ? 'E segment lüks, üst düzey konfor'
              : 'E segment luxury, top-level comfort';
        case 'B5':
          return currentLanguage == 'tr'
              ? 'Sportif coupe, zarif tasarım'
              : 'Sporty coupe, elegant design';
      }
    }
    // Hondaro modelleri için açıklamalar
    else if (brandName == 'Hondaro') {
      switch (modelName) {
        case 'Vice':
          return currentLanguage == 'tr'
              ? 'İkinci el kralı, CVT güvenilirlik'
              : 'Used car king, CVT reliability';
        case 'VHL':
          return currentLanguage == 'tr'
              ? 'SUV konforu, hibrit teknoloji'
              : 'SUV comfort, hybrid technology';
        case 'Kent':
          return currentLanguage == 'tr'
              ? 'Ekonomik sedan, yüksek güç'
              : 'Economic sedan, high power';
        case 'Caz':
          return currentLanguage == 'tr'
              ? 'Sihirli koltuk, hibrit mevcut'
              : 'Magic seats, hybrid available';
      }
    }
    return null;
  }
}

