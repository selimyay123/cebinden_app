import 'dart:async';
import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import 'vehicle_list_screen.dart';
import 'model_selection_screen.dart';

import '../models/user_model.dart';
import '../services/database_helper.dart';
import '../services/skill_service.dart';
import 'vehicle_detail_screen.dart';
import '../widgets/game_image.dart';

import 'package:lottie/lottie.dart';
import '../services/game_time_service.dart';

class BrandSelectionScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;

  const BrandSelectionScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
  });

  @override
  State<BrandSelectionScreen> createState() => _BrandSelectionScreenState();
}

class _BrandSelectionScreenState extends State<BrandSelectionScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final SkillService _skillService = SkillService();
  final GameTimeService _gameTime = GameTimeService();
  User? _currentUser;
  bool _isLoading = true;

  StreamSubscription? _userUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadUser();
    // Gün değişimini dinle (Hızlı Al hakkını güncellemek için)
    _gameTime.currentGameDay.addListener(_onDayChanged);

    // Kullanıcı güncellemelerini dinle (Skill unlock vb. için)
    _userUpdateSubscription = _db.onUserUpdate.listen((_) {
      _loadUser();
    });
  }

  @override
  void dispose() {
    _gameTime.currentGameDay.removeListener(_onDayChanged);
    _userUpdateSubscription?.cancel();
    super.dispose();
  }

  void _onDayChanged() {
    // Gün değiştiğinde UI'ı güncelle
    if (mounted) setState(() {});
  }

  Future<void> _loadUser() async {
    final userMap = await _db.getCurrentUser();
    if (userMap != null) {
      if (mounted) {
        setState(() {
          _currentUser = User.fromJson(userMap);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder ile dil değişikliklerini dinle
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        return WillPopScope(
          onWillPop: () async {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
              return false;
            }
            return true;
          },
          child: Builder(
            builder: (context) {
              // Simülasyon araç markaları (telif riski olmayan isimler)
              final brands = [
                {
                  'name': 'Audira', // Audi
                  'originalHint': 'Alman lüks performansı',
                  'color': Colors.grey[800]!,
                  'icon': 'A',
                  'imagePath': 'assets/images/brands/audira.png',
                },
                {
                  'name': 'Bavora', // BMW
                  'originalHint': 'Bavyera motoru',
                  'color': Colors.blue[700]!,
                  'icon': 'B',
                  'imagePath': 'assets/images/brands/bavora.png',
                },
                {
                  'name': 'Fialto', // Fiat
                  'originalHint': 'İtalyan pratikliği',
                  'color': Colors.red[600]!,
                  'icon': 'F',
                  'imagePath': 'assets/images/brands/fialto.png',
                },
                {
                  'name': 'Fortran', // Ford
                  'originalHint': 'Amerikan klasiği',
                  'color': Colors.blue[900]!,
                  'icon': 'F',
                  'imagePath': 'assets/images/brands/fortran.png',
                },
                // {
                //   'name': 'Hundar', // Hyundai
                //   'originalHint': 'Kore teknolojisi',
                //   'color': Colors.grey[700]!,
                //   'icon': 'H',
                //   'imagePath': 'assets/images/brands/hundar.png',
                // },
                {
                  'name': 'Hanto',
                  'originalHint': 'Japon güvenilirliği',
                  'color': Colors.red[700]!,
                  'icon': 'H',
                  'imagePath': 'assets/images/brands/hanto.png',
                },
                {
                  'name': 'Mercurion', // Mercedes
                  'originalHint': 'Alman lüksü',
                  'color': Colors.grey[600]!,
                  'icon': 'M',
                  'imagePath': 'assets/images/brands/mercurion.png',
                },
                {
                  'name': 'Oplon', // Opel
                  'originalHint': 'Alman pratikliği',
                  'color': Colors.yellow[700]!,
                  'icon': 'O',
                  'imagePath': 'assets/images/brands/oplon.png',
                },
                {
                  'name': 'Renauva', // Renault
                  'originalHint': 'Fransız inovasyonu',
                  'color': Colors.yellow[800]!,
                  'icon': 'R',
                  'imagePath': 'assets/images/brands/renauva.png',
                },
                {
                  'name': 'Koyoro', // Toyota
                  'originalHint': 'Japon mükemmelliği',
                  'color': Colors.red[600]!,
                  'icon': 'T',
                  'imagePath': 'assets/images/brands/koyoro.png',
                },
                {
                  'name': 'Volkstar', // Volkswagen
                  'originalHint': 'Halkın arabası',
                  'color': Colors.blue[700]!,
                  'icon': 'V',
                  'imagePath': 'assets/images/brands/volkstar.png',
                },
              ];

              // Alfabetik sırala
              brands.sort(
                (a, b) => (a['name'] as String).compareTo(b['name'] as String),
              );

              return Scaffold(
                backgroundColor:
                    Colors.transparent, // Gradient için transparent yapıyoruz
                extendBodyBehindAppBar:
                    true, // Gradient'in AppBar arkasına geçmesi için (isteğe bağlı, şimdilik normal bırakalım)
                appBar: AppBar(
                  title: Text('vehicles.selectBrand'.tr()),
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            // AppBar ve Status Bar yüksekliği kadar boşluk bırak
                            SizedBox(
                              height:
                                  kToolbarHeight +
                                  MediaQuery.of(context).padding.top,
                            ),

                            // Bilgilendirme Banner
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              color: widget.categoryColor.withOpacity(0.1),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.deepPurpleAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${'vehicles.categoryInfoAuto'.tr()} ${widget.categoryName}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black,
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
                                itemCount:
                                    brands.length +
                                    2, // +1 for "Tüm Modeller", +1 for "Rastgele Marka"
                                itemBuilder: (context, index) {
                                  // İlk item "Tüm Modeller"
                                  if (index == 0) {
                                    return Column(
                                      children: [
                                        _buildAllBrandsCard(context),
                                        if (_currentUser != null &&
                                            _skillService.getSkillLevel(
                                                  _currentUser!,
                                                  SkillService.skillQuickBuy,
                                                ) >
                                                0)
                                          _buildQuickBuyCard(context),
                                      ],
                                    );
                                  }

                                  // İkinci item "Rastgele Marka"
                                  if (index == 1) {
                                    return _buildRandomBrandCard(
                                      context,
                                      brands,
                                    );
                                  }

                                  // Diğer markalar
                                  final brand = brands[index - 2];
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRandomBrandCard(
    BuildContext context,
    List<Map<String, Object>> brands,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.purpleAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        shadowColor: Colors.purple.withOpacity(0.3),
        child: InkWell(
          onTap: () async {
            // Rastgele bir marka seç
            final randomBrand = (brands..shuffle()).first;

            // Seçilen markaya göre MODEL SEÇİM sayfasına git
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModelSelectionScreen(
                  categoryName: widget.categoryName,
                  categoryColor: widget.categoryColor,
                  brandName: randomBrand['name'] as String,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(
              children: [
                // Icon
                const Icon(Icons.shuffle, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Text(
                    'vehicles.randomBrandSelect'.tr(),
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

  Widget _buildAllBrandsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.deepPurpleAccent.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        shadowColor: widget.categoryColor.withOpacity(0.3),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VehicleListScreen(
                  categoryName: 'vehicles.allModels'.tr(),
                  categoryColor: widget.categoryColor,
                  brandName: null, // null = tüm markalar
                  modelName: null, // null = tüm modeller
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Icon
                const Icon(Icons.apps, color: Colors.white, size: 24),
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
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        child: InkWell(
          onTap: () async {
            // Seçilen markaya göre MODEL SEÇİM sayfasına git
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModelSelectionScreen(
                  categoryName: widget.categoryName,
                  categoryColor: widget.categoryColor,
                  brandName: name,
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
                  width: 54, // Increased slightly to accommodate border
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3), // Border width
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9), // Inner radius
                    ),
                    child: imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: GameImage(
                              assetPath: imagePath,
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
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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

  Widget _buildQuickBuyCard(BuildContext context) {
    final remainingUses = _skillService.getRemainingDailyUses(
      _currentUser!,
      SkillService.skillQuickBuy,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.orange.shade800.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        shadowColor: Colors.orange.withOpacity(0.3),
        child: InkWell(
          onTap: () async {
            if (remainingUses <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(duration: const Duration(milliseconds: 1500), 
                  content: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text('skills.dailyLimitReached'.tr())),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
              return;
            }

            // Animasyonu göster
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (c) => Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Lottie.asset(
                    'assets/animations/Hizli.Alici.json',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );

            // Animasyon süresi kadar bekle (örneğin 2.5 saniye)
            await Future.delayed(const Duration(milliseconds: 2500));

            try {
              final vehicle = await _skillService.findQuickBuyVehicle(
                _currentUser!,
              );

              if (mounted)
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop(); // Dialog'u kapat

              if (vehicle != null) {
                // Kullanım hakkını düş
                await _skillService.recordSkillUsage(
                  _currentUser!.id,
                  SkillService.skillQuickBuy,
                );
                await _loadUser(); // Kullanıcıyı güncelle

                if (mounted) {
                  // Detay sayfasına git
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          VehicleDetailScreen(vehicle: vehicle),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(duration: const Duration(milliseconds: 1500), 
                      content: Row(
                        children: [
                          const Icon(Icons.search_off, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(child: Text('skills.noVehicleFound'.tr())),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.orange.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              }
            } catch (e) {
              if (mounted)
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop(); // Dialog'u kapat
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(duration: const Duration(milliseconds: 1500), 
                    content: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Error: $e')),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Icon
                const Icon(Icons.flash_on, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Text(
                    'skills.quickBuy'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Remaining Uses
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$remainingUses/3',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
}
