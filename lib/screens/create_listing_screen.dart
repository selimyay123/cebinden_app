import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:math'; // Random için
import '../models/user_vehicle_model.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../services/skill_service.dart'; // Yetenek Servisi
import '../models/user_model.dart';
import '../utils/currency_input_formatter.dart';
import 'home_screen.dart';

class CreateListingScreen extends StatefulWidget {
  final UserVehicle vehicle;

  const CreateListingScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  User? _currentUser;
  


  @override
  void initState() {
    super.initState();
    // Önerilen fiyat: Satın alma fiyatı + %10
    // Yetenek çarpanını sonradan yükleyeceğiz
    final suggestedPrice = widget.vehicle.purchasePrice * 1.1;
    _priceController.text = CurrencyInputFormatter.format(suggestedPrice);
    
    _loadUserAndCalculateBonus();
  }



  Future<void> _loadUserAndCalculateBonus() async {
    final userMap = await _db.getCurrentUser();
    if (userMap != null) {
      final user = User.fromJson(userMap);
      setState(() => _currentUser = user);
      
      final multiplier = SkillService.getSellingMultiplier(user);
      
      // Ballı Dil yeteneği varsa toleransı artır
      if (user.unlockedSkills.any((s) => s.startsWith('charisma'))) {
        // Tolerans mantığı kaldırıldı
      }
      
      if (multiplier > 1.0) {
        final baseSuggested = widget.vehicle.purchasePrice * 1.1;
        final bonusSuggested = baseSuggested * multiplier;
        
        setState(() {
          _priceController.text = CurrencyInputFormatter.format(bonusSuggested);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              behavior: SnackBarBehavior.floating,
              content: Text('sell.skillBonus'.trParams({'percent': ((multiplier - 1) * 100).toStringAsFixed(0)})),
              backgroundColor: Colors.indigo.withOpacity(0.8),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Satışa koyma animasyonunu oynat
  Future<void> _playListForSaleAnimation() async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => PopScope(
        canPop: false, // Geri tuşunu devre dışı bırak
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/list_for_sale.json',
                width: 300,
                height: 300,
                repeat: false,
              ),
            ],
          ),
        ),
      ),
    );

    // Animasyon süresi kadar bekle (~2-3 saniye)
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      Navigator.of(context).pop(); // Animasyon overlay'ini kapat
    }
  }

  Future<void> _createListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final listingPrice = CurrencyInputFormatter.parse(_priceController.text);
      final listingDescription = _descriptionController.text.trim();

      final success = await _db.listVehicleForSale(
        vehicleId: widget.vehicle.id,
        listingPrice: listingPrice,
        listingDescription: listingDescription,
      );

      if (!mounted) return;

      if (success) {
        // 🎬 Satışa koyma animasyonunu oynat
        await _playListForSaleAnimation();

        // Başarı mesajı
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            content: Text('sell.listingSuccess'.tr()),
            backgroundColor: Colors.green.withOpacity(0.8),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // Başarılı olduğunu bildir
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            content: Text('sell.listingError'.tr()),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          content: Text('${'sell.listingErrorWithMessage'.tr()}: $e'),
          backgroundColor: Colors.red.withOpacity(0.8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sell.title'.tr()),
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
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Araç Bilgisi Kartı
            _buildVehicleInfoCard(),
            const SizedBox(height: 24),

            // Fiyat Girişi
            _buildPriceInput(),
            const SizedBox(height: 16),

            // Açıklama Girişi
            _buildDescriptionInput(),
            const SizedBox(height: 24),

            // Araç Özellikleri (Otomatik Dolu)
            _buildVehicleDetails(),
            const SizedBox(height: 32),

            // Satışa Çıkar Butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _createListing,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isLoading ? 'sell.creatingListing'.tr() : 'sell.listForSaleButton'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_car,
                size: 40,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vehicle.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.vehicle.year} • ${_formatNumber(widget.vehicle.mileage)} km',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${'sell.purchasePrice'.tr()}: ${_formatCurrency(widget.vehicle.purchasePrice)} TL',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInput() {
    // 🆕 DİNAMİK KÂR LİMİTİ
    // Standart limit: %15
    double profitMargin = 0.15;
    
    // Yetenek bonusu (İtibar)
    if (_currentUser != null) {
      profitMargin += SkillService.getReputationBonus(_currentUser!);
    }

    double discountRate = 0.0;

    // Eğer araç indirimli alındıysa, indirim oranı kadar ekstra kâr limiti ekle
    if (widget.vehicle.originalListingPrice != null && widget.vehicle.originalListingPrice! > widget.vehicle.purchasePrice) {
      discountRate = (widget.vehicle.originalListingPrice! - widget.vehicle.purchasePrice) / widget.vehicle.originalListingPrice!;
      profitMargin += discountRate;
    }

    final maxPrice = (widget.vehicle.purchasePrice * (1 + profitMargin)).roundToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'sell.salePriceLabel'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (discountRate > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'sell.extraMargin'.trParams({'percent': (discountRate * 100).toStringAsFixed(0)}),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyInputFormatter(),
          ],
          onChanged: (value) {
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: 'sell.priceHint'.tr(),
            prefixText: '₺ ',
            suffixText: 'TL',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[100],
            helperText: 'sell.maxPriceHint'.trParams({
              'price': _formatCurrency(maxPrice),
              'percent': (profitMargin * 100).toStringAsFixed(0),
            }),
            helperStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'sell.priceRequired'.tr();
            }
            final price = CurrencyInputFormatter.parse(value);
            if (price <= 0) {
              return 'sell.priceInvalid'.tr();
            }
            // Minimum limit removed
            if (price > maxPrice) {
              return 'sell.priceLimitExceeded'.trParams({
                'percent': (profitMargin * 100).toStringAsFixed(0),
              });
            }
            return null;
          },
        ),
        
        // 🆕 Kar/Zarar Göstergesi
        if (_priceController.text.isNotEmpty) ...[
          Builder(
            builder: (context) {
              final currentPrice = CurrencyInputFormatter.parse(_priceController.text);
              final profit = currentPrice - widget.vehicle.purchasePrice;
              final isProfit = profit >= 0;
              final profitPercent = widget.vehicle.purchasePrice > 0 
                  ? (profit / widget.vehicle.purchasePrice) * 100 
                  : 0;
              
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isProfit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isProfit ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isProfit ? Icons.trending_up : Icons.trending_down,
                      color: isProfit ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isProfit ? 'sell.profitStatus'.tr() : 'sell.lossStatus'.tr(),
                            style: TextStyle(
                              color: isProfit ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${isProfit ? '+' : ''}${_formatCurrency(profit)} TL (%${profitPercent.abs().toStringAsFixed(1)})',
                            style: TextStyle(
                              color: isProfit ? Colors.green[900] : Colors.red[900],
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDescriptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'sell.descriptionLabel'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'sell.descriptionHint'.tr(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[100],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleDetails() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'sell.vehicleFeatures'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('sell.brand'.tr(), widget.vehicle.brand),
            _buildDetailRow('sell.model'.tr(), widget.vehicle.model),
            _buildDetailRow('sell.year'.tr(), widget.vehicle.year.toString()),
            _buildDetailRow('sell.mileage'.tr(), '${_formatNumber(widget.vehicle.mileage)} km'),
            _buildDetailRow('sell.fuel'.tr(), 'vehicleAttributes.${widget.vehicle.fuelType}'.tr()),
            _buildDetailRow('sell.transmission'.tr(), 'vehicleAttributes.${widget.vehicle.transmission}'.tr()),
            _buildDetailRow('sell.engine'.tr(), widget.vehicle.engineSize),
            _buildDetailRow('sell.drive'.tr(), 'vehicleAttributes.${widget.vehicle.driveType}'.tr()),
            _buildDetailRow('sell.color'.tr(), 'colors.${widget.vehicle.color}'.tr()),
            _buildDetailRow('sell.warranty'.tr(), widget.vehicle.hasWarranty ? 'sell.var'.tr() : 'sell.yok'.tr()),
            _buildDetailRow('sell.accidentRecord'.tr(), widget.vehicle.hasAccidentRecord ? 'sell.var'.tr() : 'sell.yok'.tr()),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

