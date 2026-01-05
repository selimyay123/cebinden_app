import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/market_refresh_service.dart';
import '../utils/vehicle_utils.dart';
import 'vehicle_list_screen.dart';
import 'main_screen.dart';

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
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text('vehicles.selectModel'.tr()),
            backgroundColor: categoryColor.withOpacity(0.9),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/general_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Column(
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
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
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
                      itemCount: models.length + 2, // +1 for "Tüm Modeller", +1 for "Rastgele Model"
                      itemBuilder: (context, index) {
                        // İlk item "Tüm Modeller"
                        if (index == 0) {
                          return _buildAllModelsCard(context, currentLanguage);
                        }

                        // İkinci item "Rastgele Model"
                        if (index == 1) {
                          return _buildRandomModelCard(context, models);
                        }
                        
                        // Diğer modeller
                        final model = models[index - 2];
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildRandomModelCard(BuildContext context, List<String> models) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.purpleAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        shadowColor: Colors.purple.withOpacity(0.3),
        child: InkWell(
          onTap: () async {
            // Rastgele bir model seç
            final randomModel = (models..toList()..shuffle()).first;
            
            // Seçilen modele göre araç listesi sayfasına git
            final purchased = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VehicleListScreen(
                  categoryName: '$brandName - $randomModel',
                  categoryColor: categoryColor,
                  brandName: brandName,
                  modelName: randomModel,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Icon
                const Icon(
                  Icons.shuffle,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Text(
                    'vehicles.randomModelSelect'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Arrow
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllModelsCard(BuildContext context, String currentLanguage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.deepPurpleAccent.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        shadowColor: categoryColor.withOpacity(0.3),
        child: InkWell(
          onTap: () async {
            final purchased = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VehicleListScreen(
                  categoryName: '$brandName - ${'vehicles.allModels'.tr()}',
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Icon
                const Icon(
                  Icons.apps,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Text(
                    'vehicles.allModels'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Arrow
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
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
    
    // Model resmi (varsa)
    final modelImage = _getModelImage(brandName, modelName);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withOpacity(0.7),
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
                  categoryName: '$brandName - $modelName',
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
                // Model İkonu veya Resmi
                Container(
                  width: modelImage != null ? 90 : 60, // Resim varsa daha geniş
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: categoryColor.withOpacity(0.3),
                      width: 1, // Daha ince çerçeve
                    ),
                    image: modelImage != null ? DecorationImage(
                      image: AssetImage(modelImage),
                      fit: BoxFit.contain,
                    ) : null,
                  ),
                  child: modelImage == null ? Center(
                    child: Text(
                      modelIcon,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ) : null,
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

  String? _getModelImage(String brandName, String modelName) {
    return VehicleUtils.getVehicleImage(brandName, modelName, index: 1);
  }
}

