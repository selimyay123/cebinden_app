import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../services/iap_service.dart';
import '../models/user_model.dart';
import '../widgets/modern_alert_dialog.dart';
import '../widgets/custom_snackbar.dart';
import 'main_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  final IAPService _iapService = IAPService();
  late StreamSubscription<String> _purchaseSubscription;
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _iapService.initialize();
    _purchaseSubscription = _iapService.purchaseEvents.listen(_handlePurchaseEvent);
  }

  @override
  void dispose() {
    _purchaseSubscription.cancel();
    super.dispose();
  }

  void _handlePurchaseEvent(String event) {
    if (event == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        CustomSnackBar(
          content: Text('store.purchaseSuccess'.tr()),
          backgroundColor: Colors.green,
        ),
      );
      _loadCurrentUser(); // Bakiyeyi güncelle
    } else if (event.startsWith('error:')) {
      final rawError = event.substring(7);
      final errorMessage = _getLocalizedErrorMessage(rawError);
      
      ScaffoldMessenger.of(context).showSnackBar(
        CustomSnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } else if (event.startsWith('info:')) {
      final infoMessage = event.substring(6); // 'info: ' length
      ScaffoldMessenger.of(context).showSnackBar(
        CustomSnackBar(
          content: Text(infoMessage),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  String _getLocalizedErrorMessage(String error) {
    if (error.contains('BillingResponse.itemUnavailable')) {
      return 'store.errorItemUnavailable'.tr();
    } else if (error.contains('BillingResponse.serviceUnavailable')) {
      return 'store.errorServiceUnavailable'.tr();
    } else if (error.contains('BillingResponse.userCanceled')) {
      return 'store.errorUserCanceled'.tr();
    } else if (error.contains('BillingResponse.itemAlreadyOwned')) {
      return 'store.errorItemUnavailable'.tr(); // Already owned treated as unavailable for consumable logic or similar
    }
    
    // Fallback for unknown errors, but try to be helpful if it's a readable string
    if (error.isNotEmpty && !error.contains('BillingResponse')) {
       return error; 
    }
    
    return 'store.errorUnknown'.tr();
  }

  Future<void> _loadCurrentUser() async {
    setState(() => _isLoading = true);
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          child: Scaffold(
          // backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text('store.title'.tr()),
            actions: [
              if (_currentUser?.email == 'selimyay123@gmail.com')
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.red),
                  onPressed: () async {
                    await _db.updateUser(_currentUser!.id, {
                      'ownsGallery': false,
                      'hasUnlimitedExpertise': false,
                      'hasNoAds': false,
                      'xpBoostEndTime': null,
                    });
                    await _loadCurrentUser();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        CustomSnackBar(content: const Text('VIP Status Reset!')),
                      );
                    }
                  },
                ),
            ],
            backgroundColor: Colors.deepPurple,
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentUser == null
                    ? Center(child: Text('common.userNotFound'.tr()))
                    : RefreshIndicator(
                        onRefresh: _loadCurrentUser,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Bakiye Kartı
                                  _buildBalanceCard(),
                                  const SizedBox(height: 24),
                                  
                                  // Altın Satın Alma Paketleri
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle('store.buyGold'.tr()),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 16),
                                        child: Text(
                                          '1 ${'store.gold'.tr()} = 1.000.000 ${'store.gameCurrency'.tr()}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildGoldPackages(),

                                  const SizedBox(height: 32),

                                  // Garaj Genişletme (Yükseltmeler)
                                  _buildSectionTitle('store.garageExpansion'.tr()),
                                  const SizedBox(height: 12),
                                  _buildGalleryPurchaseCard(),
                                  const SizedBox(height: 12),
                                  _buildGarageExpansionCard(),
                                  const SizedBox(height: 12),
                                  _buildUnlimitedExpertiseCard(),
                                  const SizedBox(height: 12),
                                  _buildXpBoostCard(),
                                  const SizedBox(height: 12),
                                  _buildRemoveAdsCard(),
                                  const SizedBox(height: 12),

                                  const SizedBox(height: 32),

                                  // Animasyonlu Profil Resimleri
                                  _buildSectionTitle('store.animatedPP.title'.tr()),
                                  const SizedBox(height: 12),
                                  _buildAnimatedPPSection(),
                                  const SizedBox(height: 12),

                                  const SizedBox(height: 20),
                                  _buildVipPassCard(),
                                  const SizedBox(height: 32),

                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildGalleryPurchaseCard() {
    final isOwned = _currentUser!.ownsGallery;
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 24),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Lottie.asset(
              'assets/animations/level_up.json',
              width: 70,
              height: 70,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home.buyGallery'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          isOwned
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 24),
                )
              : ElevatedButton(
                  onPressed: () => _showBuyGalleryDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '5',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Lottie.asset(
                        'assets/animations/gold.json',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  void _showBuyGalleryDialog() {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'home.buyGallery'.tr(),
        // icon: Icons.store_mall_directory, // Removed
        // iconColor: Colors.deepPurple, // Removed
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Benefits List
            _buildGalleryBenefit(
              icon: Icons.key,
              title: 'home.advantage1Title'.tr(),
            ),
            const SizedBox(height: 12),
            _buildGalleryBenefit(
              icon: Icons.local_offer,
              title: 'home.advantage2Title'.tr(),
            ),
            const SizedBox(height: 12),
            _buildGalleryBenefit(
              icon: Icons.trending_up,
              title: 'home.advantage3Title'.tr(),
            ),
            const SizedBox(height: 12),
            _buildGalleryBenefit(
              icon: Icons.verified,
              title: 'home.advantage4Title'.tr(),
            ),
            const SizedBox(height: 12),
            _buildGalleryBenefit(
              icon: Icons.garage,
              title: 'home.advantage5Title'.tr(),
            ),
            const SizedBox(height: 24),
            Text(
              'store.costLabel'.trParams({
                'amount': '5',
                'currency': 'store.gold'.tr()
              }),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        buttonText: 'store.buy'.tr(),
        onPressed: () async {
          if (_currentUser!.gold >= 5) {
            Navigator.pop(context);
            
            // Altını düş ve galeri özelliklerini ekle
            final newGold = _currentUser!.gold - 5;
            final newGarageLimit = _currentUser!.garageLimit + 5; // Galeri ile +5 limit
            
            await _db.updateUser(_currentUser!.id, {
              'gold': newGold,
              'ownsGallery': true,
              'galleryPurchaseDate': DateTime.now().toIso8601String(),
              'garageLimit': newGarageLimit,
            });
            
            await _loadCurrentUser();
            
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => ModernAlertDialog(
                  title: 'home.galleryPurchaseSuccess'.tr(),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.celebration,
                        size: 60,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'home.galleryDescription'.tr(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  buttonText: 'common.ok'.tr(),
                  onPressed: () => Navigator.pop(context),
                ),
              );
            }
          } else {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              CustomSnackBar(
                content: Text('store.insufficientGold'.tr()),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildGalleryBenefit({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 13,
            ),
          ),
        ),
        const Icon(
          Icons.check_circle,
          color: Colors.white,
          size: 16,
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade700, Colors.amber.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'store.yourGold'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentUser!.gold.toStringAsFixed(2)} ${'store.gold'.tr()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Convert Gold Button
                  ElevatedButton(
                    onPressed: _currentUser!.gold > 0 ? () => _showConvertGoldDialog() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    child: Row(
                      children: [
                        const Icon(Icons.currency_exchange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'store.convertGold'.tr(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'home.balance'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_formatCurrency(_currentUser!.balance)} TL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGarageExpansionCard() {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 24),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12), // Reduced padding for animation
            child: Lottie.asset(
              'assets/animations/level_up.json',
              width: 70,
              height: 70,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'store.garageCapacity'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showExpandGarageDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '1',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Lottie.asset(
                  'assets/animations/gold.json',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveAdsCard() {
    final isOwned = _currentUser!.hasNoAds;
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 24),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Lottie.asset(
              'assets/animations/level_up.json', // Using level_up as generic upgrade animation
              width: 70,
              height: 70,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'store.removeAds'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                // Text(
                //   'store.removeAdsDesc'.tr(),
                //   style: TextStyle(
                //     fontSize: 12,
                //     color: Colors.white.withOpacity(0.8),
                //   ),
                // ),
              ],
            ),
          ),
          isOwned
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 24),
                )
              : ElevatedButton(
                  onPressed: () => _showRemoveAdsDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '5',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Lottie.asset(
                        'assets/animations/gold.json',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  void _showRemoveAdsDialog() {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'store.removeAds'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.block,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'store.removeAdsDialogDesc'.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'store.costLabel'.trParams({
                'amount': '5',
                'currency': 'store.gold'.tr()
              }),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        buttonText: 'store.buy'.tr(),
        onPressed: () async {
          if (_currentUser!.gold >= 5) {
            Navigator.pop(context);
            
            // Altını düş ve özelliği ekle
            final newGold = _currentUser!.gold - 5;
            
            await _db.updateUser(_currentUser!.id, {
              'gold': newGold,
              'hasNoAds': true,
            });
            
            await _loadCurrentUser();
            
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => ModernAlertDialog(
                  title: 'store.removeAdsSuccess'.tr(),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.celebration,
                        size: 60,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'store.removeAdsSuccessDesc'.tr(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  buttonText: 'common.ok'.tr(),
                  onPressed: () => Navigator.pop(context),
                ),
              );
            }
          } else {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              CustomSnackBar(
                content: Text('store.insufficientGold'.tr()),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatProductPrice(ProductDetails product) {
    // Bazı cihazlarda ₺ sembolü düzgün görüntülenemiyor (mor çubuk sorunu)
    // Bu yüzden TRY kodu varsa sembolü TL ile değiştiriyoruz
    if (product.currencyCode == 'TRY') {
      return product.price.replaceAll('₺', 'TL').replaceAll('TL', 'TL'); // İkinci replace garanti olsun diye
    }
    return product.price;
  }

  Widget _buildGoldPackages() {
    return ValueListenableBuilder<String?>(
      valueListenable: _iapService.errorNotifier,
      builder: (context, error, child) {
        if (error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'store.productsLoadError'.tr(), // Add this key or use fallback
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _iapService.initialize();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text('common.retry'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ValueListenableBuilder<List<ProductDetails>>(
          valueListenable: _iapService.productsNotifier,
          builder: (context, products, child) {
            if (products.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text('store.loadingProducts'.tr()),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: products.map((product) {
            // Bonus hesaplama (ID'ye göre)
            int bonus = 0;
            int goldAmount = 0;
            
            if (product.id.contains('01')) {
              goldAmount = 1;
              bonus = 0;
            } else if (product.id.contains('05')) {
              goldAmount = 5;
              bonus = 50;
            } else if (product.id.contains('10')) {
              goldAmount = 10;
              bonus = 150;
            } else if (product.id.contains('25')) {
              goldAmount = 25;
              bonus = 500;
            }
            
            final hasBonus = bonus > 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                elevation: 2,
                child: InkWell(
                  onTap: () => _showPurchaseDialog(product, goldAmount, bonus),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // İkon
                        Container(
                          width: 60,
                          height: 60,
                          child: Lottie.asset(
                            'assets/animations/gold.json',
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Bilgiler
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                product.title.replaceAll(RegExp(r'\(.*\)'), '').trim(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(goldAmount * 1000000.0),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Fiyat
                        Text(
                          _formatProductPrice(product),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
      },
    );
  }



  void _showPurchaseDialog(ProductDetails product, int gold, int bonus) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _iapService.purchasePendingNotifier,
        builder: (context, isPending, child) {
          return ModernAlertDialog(
            title: 'store.purchaseGold'.tr(),
            icon: Icons.shopping_cart,
            iconColor: Colors.amber,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'store.package'.tr(),
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              product.title.replaceAll(RegExp(r'\(.*\)'), '').trim(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'store.price'.tr(),
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          Text(
                            _formatProductPrice(product),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (isPending)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('common.pleaseWait'.tr()),
                    ],
                  )
                else
                  Text(
                    'store.securePaymentMessage'.tr(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
            buttonText: isPending ? null : 'store.buy'.tr(),
            onPressed: isPending
                ? null
                : () {
                    _iapService.buyProduct(product);
                    Navigator.pop(context);
                  },
            secondaryButtonText: isPending ? null : 'common.cancel'.tr(),
            onSecondaryPressed: isPending ? null : () => Navigator.pop(context),
          );
        },
      ),
    );
  }

  void _showExpandGarageDialog() {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'store.expandGarageTitle'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'store.currentLimitLabel'.trParams({'limit': _currentUser!.garageLimit.toString()}),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Icon(Icons.arrow_downward, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              'store.newLimitLabel'.trParams({'limit': (_currentUser!.garageLimit + 1).toString()}),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'store.costLabel'.trParams({
                'amount': '1',
                'currency': 'store.gold'.tr()
              }),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        buttonText: 'store.buy'.tr(),
        onPressed: () async {
          if (_currentUser!.gold >= 1) {
            Navigator.pop(context);
            
            // Altını düş ve limiti artır
            final newGold = _currentUser!.gold - 1;
            final newLimit = _currentUser!.garageLimit + 1;
            
            await _db.updateUser(_currentUser!.id, {
              'gold': newGold,
              'garageLimit': newLimit,
            });
            
            await _loadCurrentUser();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                CustomSnackBar(
                  content: Text('store.garageExpandSuccess'.tr()),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              CustomSnackBar(
                content: Text('store.insufficientGold'.tr()),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildUnlimitedExpertiseCard() {
    final isOwned = _currentUser!.hasUnlimitedExpertise;
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 24),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Lottie.asset(
              'assets/animations/level_up.json',
              width: 70,
              height: 70,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'skills.unlimitedExpertiseTitle'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          isOwned
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 24),
                )
              : ElevatedButton(
                  onPressed: () => _showBuyUnlimitedExpertiseDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '1',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Lottie.asset(
                        'assets/animations/gold.json',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  void _showBuyUnlimitedExpertiseDialog() {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'skills.unlimitedExpertiseTitle'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'skills.unlimitedExpertiseDesc'.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'store.costLabel'.trParams({
                'amount': '1',
                'currency': 'store.gold'.tr()
              }),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        buttonText: 'store.buy'.tr(),
        onPressed: () async {
          if (_currentUser!.gold >= 1) {
            Navigator.pop(context);

            final newGold = _currentUser!.gold - 1;

            await _db.updateUser(_currentUser!.id, {
              'gold': newGold,
              'hasUnlimitedExpertise': true,
            });

            await _loadCurrentUser();

            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => ModernAlertDialog(
                  title: 'common.success'.tr(),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.celebration,
                        size: 60,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'skills.unlimitedExpertiseTitle'.tr(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  buttonText: 'common.ok'.tr(),
                  onPressed: () => Navigator.pop(context),
                ),
              );
            }
          } else {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              CustomSnackBar(
                content: Text('store.insufficientGold'.tr()),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildXpBoostCard() {
    final now = DateTime.now();
    final isActive = _currentUser!.xpBoostEndTime != null && _currentUser!.xpBoostEndTime!.isAfter(now);

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 24),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Lottie.asset(
              'assets/animations/level_up.json',
              width: 70,
              height: 70,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'skills.xpBoostTitle'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (isActive)
                  Text(
                    '${'common.active'.tr()} (${_currentUser!.xpBoostEndTime!.difference(now).inHours}s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          isActive
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 24),
                )
              : ElevatedButton(
                  onPressed: () => _showBuyXpBoostDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '1',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Lottie.asset(
                        'assets/animations/gold.json',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  void _showBuyXpBoostDialog() {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'skills.xpBoostTitle'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'skills.xpBoostDesc'.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'store.costLabel'.trParams({
                'amount': '1',
                'currency': 'store.gold'.tr()
              }),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        buttonText: 'store.buy'.tr(),
        onPressed: () async {
          if (_currentUser!.gold >= 1) {
            Navigator.pop(context);

            final newGold = _currentUser!.gold - 1;
            
            // Mevcut bitiş zamanını al veya şimdiye ayarla
            DateTime currentEndTime = _currentUser!.xpBoostEndTime ?? DateTime.now();
            if (currentEndTime.isBefore(DateTime.now())) {
              currentEndTime = DateTime.now();
            }
            
            // 24 saat ekle
            final newEndTime = currentEndTime.add(const Duration(hours: 24));

            await _db.updateUser(_currentUser!.id, {
              'gold': newGold,
              'xpBoostEndTime': newEndTime.toIso8601String(),
            });

            await _loadCurrentUser();

            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => ModernAlertDialog(
                  title: 'common.success'.tr(),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.celebration,
                        size: 60,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'skills.xpBoostSuccess'.tr(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  buttonText: 'common.ok'.tr(),
                  onPressed: () => Navigator.pop(context),
                ),
              );
            }
          } else {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              CustomSnackBar(
                content: Text('store.insufficientGold'.tr()),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  void _showConvertGoldDialog() {
    final maxGold = _currentUser!.gold; // Tüm altınları bozdurabilir (double)
    double selectedGold = 0.1; // 0.1'den başlasın
    
    final TextEditingController controller = TextEditingController(text: '0.1');
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String? validationError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.currency_exchange, color: Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('store.convertGold'.tr())),
                ],
              ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'store.selectAmount'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Input alanı + ve - butonları ile
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          double currentVal = double.tryParse(controller.text) ?? 0.1;
                          if (currentVal > 0.1) {
                            currentVal -= 0.1;
                            controller.text = currentVal.toStringAsFixed(1);
                            selectedGold = currentVal;
                            setDialogState(() {});
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.red,
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            suffixText: 'store.gold'.tr(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (value) {
                            final val = double.tryParse(value);
                            if (val != null) {
                              selectedGold = val;
                              setDialogState(() {});
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'store.enterAmount'.tr();
                            }
                            final val = double.tryParse(value);
                            if (val == null) {
                              return 'store.invalidNumber'.tr();
                            }
                            if (val < 0.1) {
                              return 'store.minAmount'.tr() + ': 0.1';
                            }
                            if (val > maxGold) {
                              return 'store.insufficientGoldError'.trParams({'amount': maxGold.toStringAsFixed(2)});
                            }
                            return null;
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          double currentVal = double.tryParse(controller.text) ?? 0.1;
                          if (currentVal < maxGold) {
                            currentVal += 0.1;
                            controller.text = currentVal.toStringAsFixed(1);
                            selectedGold = currentVal;
                            setDialogState(() {});
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.green,
                      ),
                    ],
                  ),
                  // Hızlı Seçim Butonları
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (1 <= maxGold) {
                                  controller.text = '1';
                                  selectedGold = 1.0;
                                  setDialogState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.withOpacity(0.2),
                                foregroundColor: Colors.amber[900],
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('1', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (5 <= maxGold) {
                                  controller.text = '5';
                                  selectedGold = 5.0;
                                  setDialogState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.withOpacity(0.2),
                                foregroundColor: Colors.amber[900],
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('5', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (10 <= maxGold) {
                                  controller.text = '10';
                                  selectedGold = 10.0;
                                  setDialogState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.withOpacity(0.2),
                                foregroundColor: Colors.amber[900],
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('10', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (25 <= maxGold) {
                                  controller.text = '25';
                                  selectedGold = 25.0;
                                  setDialogState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.withOpacity(0.2),
                                foregroundColor: Colors.amber[900],
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('25', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Bilgi Kartı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('store.exchangeRate'.tr(), style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            const Text('1 Gold = 1.000.000 TL', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('store.youWillGet'.tr(), style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatCurrency(selectedGold * 1000000)} TL',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('store.remainingGold'.tr(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text(
                              '${(maxGold - selectedGold).toStringAsFixed(2)} Gold',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.cancel'.tr(), style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    
                    // Onay Dialogu
                    showDialog(
                      context: context,
                      builder: (context) => ModernAlertDialog(
                        title: 'store.confirmConvert'.tr(),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('store.confirmConvertMessage'.tr()),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('store.goldAmount'.tr()),
                                  Text(
                                    '${selectedGold.toStringAsFixed(1)} Gold',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Icon(Icons.arrow_downward, color: Colors.grey),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('store.gameCurrency'.tr()),
                                  Text(
                                    '${_formatCurrency(selectedGold * 1000000)} TL',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        buttonText: 'store.confirmButton'.tr(),
                        onPressed: () async {
                          Navigator.pop(context);
                          
                          // İşlemi gerçekleştir
                          final newGold = _currentUser!.gold - selectedGold;
                          final newBalance = _currentUser!.balance + (selectedGold * 1000000);
                          
                          await _db.updateUser(_currentUser!.id, {
                            'gold': newGold,
                            'balance': newBalance,
                          });
                          
                          await _loadCurrentUser();
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              CustomSnackBar(
                                content: Text('store.insufficientGold'.tr()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        secondaryButtonText: 'common.cancel'.tr(),
                        onSecondaryPressed: () => Navigator.pop(context),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('store.convert'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }



  Widget _buildVipPassCard() {
    // Check if user has all permanent items
    final hasAll = _currentUser!.ownsGallery && 
                   _currentUser!.hasUnlimitedExpertise && 
                   _currentUser!.hasNoAds;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/vip_pass_bg.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
      ),
      child: Column(
        children: [
          Column(
            children: [
              // MEMEWE Preview
              SizedBox(
                width: 100,
                height: 100,
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: ClipOval(
                      child: Lottie.asset(
                        'assets/animations/pp/MEMEWE.json',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'store.vipPass.title'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'store.vipPass.desc'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasAll)
             Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'common.active'.tr(), // Or a specific message like "VIP Active"
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _showBuyVipPassDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '10',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '5',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Lottie.asset(
                    'assets/animations/gold.json',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showBuyVipPassDialog() {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'store.vipPass.title'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'store.vipPass.dialogDesc'.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'store.costLabel'.trParams({
                      'amount': '10',
                      'currency': 'store.gold'.tr()
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'store.costLabel'.trParams({
                      'amount': '5',
                      'currency': 'store.gold'.tr()
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 20,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        buttonText: 'store.buy'.tr(),
        onPressed: () async {
          if (_currentUser!.gold >= 5) {
            Navigator.pop(context);

            final newGold = _currentUser!.gold - 5;
            final newGarageLimit = _currentUser!.ownsGallery ? _currentUser!.garageLimit : _currentUser!.garageLimit + 5;
            
            // XP Boost logic
            DateTime currentEndTime = _currentUser!.xpBoostEndTime ?? DateTime.now();
            if (currentEndTime.isBefore(DateTime.now())) {
              currentEndTime = DateTime.now();
            }
            final newEndTime = currentEndTime.add(const Duration(hours: 24));

            // Add MEMEWE to purchased animated PPs if not already owned
            List<String> newPurchasedPPs = List.from(_currentUser!.purchasedAnimatedPPs);
            if (!newPurchasedPPs.contains('MEMEWE')) {
              newPurchasedPPs.add('MEMEWE');
            }

            await _db.updateUser(_currentUser!.id, {
              'gold': newGold,
              'ownsGallery': true,
              'galleryPurchaseDate': _currentUser!.ownsGallery ? _currentUser!.galleryPurchaseDate : DateTime.now().toIso8601String(),
              'garageLimit': newGarageLimit,
              'hasUnlimitedExpertise': true,
              'hasNoAds': true,
              'xpBoostEndTime': newEndTime.toIso8601String(),
              'purchasedAnimatedPPs': newPurchasedPPs,
              'profileImageUrl': 'assets/animations/pp/MEMEWE.json',
              'activeAnimatedPP': 'MEMEWE',
            });

            await _loadCurrentUser();

            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => ModernAlertDialog(
                  title: 'common.success'.tr(),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars,
                        size: 60,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'store.vipPass.success'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'store.vipPass.successDesc'.tr(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  buttonText: 'common.ok'.tr(),
                  onPressed: () => Navigator.pop(context),
                ),
              );
            }
          } else {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              CustomSnackBar(
                content: Text('store.insufficientGold'.tr()),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildAnimatedPPSection() {
    final animations = [
      {'name': 'VK', 'key': 'store.animatedPP.names.VK', 'path': 'assets/animations/vk.json'},
      {'name': 'Money', 'key': 'store.animatedPP.names.Money', 'path': 'assets/animations/pp/Money.json'},
      {'name': 'PEPE', 'key': 'store.animatedPP.names.PEPE', 'path': 'assets/animations/pp/PEPE.json'},
      {'name': 'Cool emoji', 'key': 'store.animatedPP.names.CoolEmoji', 'path': 'assets/animations/pp/Cool emoji.json'},
      {'name': 'Pepe Sticker Music', 'key': 'store.animatedPP.names.PepeMusic', 'path': 'assets/animations/pp/Pepe Sticker Music.json'},
      {'name': 'The Nyan Cat', 'key': 'store.animatedPP.names.NyanCat', 'path': 'assets/animations/pp/The Nyan Cat.json'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: animations.length,
      itemBuilder: (context, index) {
        final anim = animations[index];
        final isPurchased = _currentUser!.purchasedAnimatedPPs.contains(anim['name']);
        final isActive = _currentUser!.activeAnimatedPP == anim['name'];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: ClipOval(
                  child: Lottie.asset(
                    anim['path']!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                anim['key']!.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (isActive)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  child: Text(
                    'store.animatedPP.active'.tr(),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (isPurchased)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _activatePP(anim['name']!, anim['path']!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('store.animatedPP.activate'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _purchasePP(anim['name']!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '1',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Lottie.asset(
                          'assets/animations/gold.json',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _purchasePP(String name) async {
    if (_currentUser!.gold < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        CustomSnackBar(content: Text('store.animatedPP.insufficientGold'.tr()), backgroundColor: Colors.red),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'store.animatedPP.buy'.tr(),
        icon: Icons.face,
        iconColor: Colors.deepPurple,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${name} ${'store.animatedPP.price'.tr()}?',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'store.costLabel'.trParams({
                'amount': '1',
                'currency': 'store.gold'.tr()
              }),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        buttonText: 'store.animatedPP.buy'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed == true) {
      final newList = List<String>.from(_currentUser!.purchasedAnimatedPPs)..add(name);
      await _db.updateUser(_currentUser!.id, {
        'gold': _currentUser!.gold - 1,
        'purchasedAnimatedPPs': newList,
      });
      await _loadCurrentUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          CustomSnackBar(content: Text('store.animatedPP.purchaseSuccess'.tr()), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _activatePP(String name, String path) async {
    await _db.updateUser(_currentUser!.id, {
      'activeAnimatedPP': name,
      'profileImageUrl': path,
    });
    await _loadCurrentUser();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        CustomSnackBar(content: Text('store.animatedPP.activationSuccess'.tr()), backgroundColor: Colors.green),
      );
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

