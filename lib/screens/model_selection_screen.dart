import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/market_refresh_service.dart';
import 'vehicle_list_screen.dart';
import 'home_screen.dart';

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
            title: Text('vehicles.selectModel'.tr()),
            actions: [
              IconButton(
                icon: const Icon(Icons.home),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
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
                        'vehicles.whichModelPrefer'.trParams({'brand': brandName}),
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
                        'vehicles.viewAllModelsOfBrand'.trParams({'brand': brandName}),
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
                        modelName.replaceAll('Serisi', 'vehicles.series'.tr()),
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
    return 'models.descriptions.$brandName.$modelName'.tr();
  }
}

