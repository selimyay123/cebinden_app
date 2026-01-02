import 'dart:async';
import 'package:flutter/material.dart';

import '../services/localization_service.dart';
import '../services/market_refresh_service.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/vehicle_utils.dart';
import 'package:google_fonts/google_fonts.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final MarketRefreshService _marketService = MarketRefreshService();
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();

  Map<String, List<String>> _modelsByBrand = {};
  Set<String> _ownedModelKeys = {};
  User? _user;
  bool _isLoading = true;
  StreamSubscription? _vehicleSubscription;

  final Map<String, Map<String, dynamic>> _brandRewards = {
    'Audira': {'money': 500000.0, 'xp': 5000},
    'Bavora': {'money': 500000.0, 'xp': 5000},
    'Mercurion': {'money': 500000.0, 'xp': 5000},
    'Fortran': {'money': 200000.0, 'xp': 2000},
    'Hanto': {'money': 200000.0, 'xp': 2000},
    'Oplon': {'money': 200000.0, 'xp': 2000},
    'Renauva': {'money': 200000.0, 'xp': 2000},
    'Koyoro': {'money': 200000.0, 'xp': 2000},
    'Volkstar': {'money': 200000.0, 'xp': 2000},
    'Fialto': {'money': 100000.0, 'xp': 1000},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Araç değişikliklerini dinle
    _vehicleSubscription = _db.onVehicleUpdate.listen((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _vehicleSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final user = await _authService.getCurrentUser();
    if (user != null) {
      _user = user;
      _modelsByBrand = _marketService.modelsByBrand;
      _ownedModelKeys = await _db.getOwnedModelKeys(user.id);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'drawer.collection'.tr(),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/home_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : ListView.builder(
                padding: const EdgeInsets.only(
                  top: kToolbarHeight + 80, // Üst boşluk artırıldı
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                itemCount: _modelsByBrand.length,
                itemBuilder: (context, index) {
                  final brand = _modelsByBrand.keys.elementAt(index);
                  final models = _modelsByBrand[brand]!;
                  
                  return _buildBrandSection(brand, models);
                },
              ),
      ),
    );
  }

  Widget _buildBrandSection(String brand, List<String> models) {
    // Bu markaya ait kaç modele sahip olunduğunu hesapla
    int ownedInBrand = models.where((m) => _ownedModelKeys.contains('${brand}_$m')).length;
    bool allOwned = ownedInBrand == models.length;
    bool alreadyCollected = _user?.collectedBrandRewards.contains(brand) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), // Üst ve alt boşluk azaltıldı
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Image.asset(
                      'assets/images/brands/${brand.toLowerCase()}.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.directions_car, size: 32, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$ownedInBrand / ${models.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildCollectButton(brand, allOwned, alreadyCollected),
            ],
          ),
        ),
        GridView.builder(
          padding: EdgeInsets.zero, // GridView'ın varsayılan padding'i sıfırlandı
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: models.length,
          itemBuilder: (context, index) {
            final model = models[index];
            final isOwned = _ownedModelKeys.contains('${brand}_$model');
            return _buildModelCard(brand, model, isOwned);
          },
        ),
        const SizedBox(height: 16), // Bölümler arası boşluk azaltıldı
      ],
    );
  }

  Widget _buildModelCard(String brand, String model, bool isOwned) {
    final imageUrl = VehicleUtils.getVehicleImage(brand, model, index: 1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: imageUrl != null
                  ? ColorFiltered(
                      colorFilter: isOwned
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                          : ColorFilter.mode(Colors.grey.shade300, BlendMode.srcIn),
                      child: Image.asset(
                        imageUrl,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const Icon(Icons.directions_car, size: 48, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
            child: Text(
              model,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isOwned ? FontWeight.w600 : FontWeight.w400,
                color: isOwned ? Colors.black87 : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectButton(String brand, bool allOwned, bool alreadyCollected) {
    Color buttonColor;
    String buttonText;
    VoidCallback? onTap;

    if (alreadyCollected) {
      buttonColor = Colors.grey.shade400;
      buttonText = 'drawer.collectionRewards.collected'.tr();
      onTap = null;
    } else if (allOwned) {
      buttonColor = Colors.green.shade600;
      buttonText = 'drawer.collectionRewards.collect'.tr();
      onTap = () => _collectReward(brand);
    } else {
      buttonColor = Colors.grey.shade300;
      buttonText = 'drawer.collectionRewards.collect'.tr();
      onTap = null;
    }

    return Material(
      color: buttonColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            buttonText,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _collectReward(String brand) async {
    if (_user == null) return;

    final reward = _brandRewards[brand];
    if (reward == null) return;

    final double moneyReward = reward['money'];
    final int xpReward = reward['xp'];

    // Kullanıcıyı güncelle
    final updatedCollectedRewards = List<String>.from(_user!.collectedBrandRewards)..add(brand);
    final updatedUser = _user!.copyWith(
      balance: _user!.balance + moneyReward,
      xp: _user!.xp + xpReward,
      collectedBrandRewards: updatedCollectedRewards,
    );

    // Veritabanına kaydet
    await _db.updateUser(updatedUser.id, updatedUser.toJson());
    await _loadData();

    if (mounted) {
      _showRewardSnackBar(brand, moneyReward, xpReward);
    }
  }

  void _showRewardSnackBar(String brand, double money, int xp) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'drawer.collectionRewards.rewardTitle'.tr(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'drawer.collectionRewards.rewardMessage'.trParams({
                        '0': brand,
                        '1': _formatCurrency(money),
                        '2': xp.toString(),
                      }),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
