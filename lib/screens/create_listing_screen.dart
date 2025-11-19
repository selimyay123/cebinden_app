import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_vehicle_model.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Önerilen fiyat: Satın alma fiyatı + %10
    final suggestedPrice = widget.vehicle.purchasePrice * 1.1;
    _priceController.text = suggestedPrice.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final listingPrice = double.parse(_priceController.text);
      final listingDescription = _descriptionController.text.trim();

      final success = await _db.listVehicleForSale(
        vehicleId: widget.vehicle.id,
        listingPrice: listingPrice,
        listingDescription: listingDescription,
      );

      if (!mounted) return;

      if (success) {
        // Başarı mesajı
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('sell.listingSuccess'.tr()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // Başarılı olduğunu bildir
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('sell.listingError'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'sell.listingErrorWithMessage'.tr()}: $e'),
          backgroundColor: Colors.red,
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
                label: Text(_isLoading ? 'İlan Oluşturuluyor...' : 'Satışa Çıkar'),
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
                    'Satın Alma: ${_formatCurrency(widget.vehicle.purchasePrice)} TL',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Satış Fiyatı *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: 'Örn: 350000',
            prefixText: '₺ ',
            suffixText: 'TL',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[100],
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Fiyat girmelisiniz';
            }
            final price = double.tryParse(value);
            if (price == null || price <= 0) {
              return 'Geçerli bir fiyat girin';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Önerilen fiyat: ${_formatCurrency(widget.vehicle.purchasePrice * 1.1)} TL (Alış fiyatı + %10)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İlan Açıklaması *',
          style: TextStyle(
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
            hintText: 'Aracınız hakkında detaylı bilgi verin...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[100],
          ),
          // validator: (value) {
          //   if (value == null || value.trim().isEmpty) {
          //     return 'Açıklama girmelisiniz';
          //   }
          //   if (value.trim().length < 20) {
          //     return 'Açıklama en az 20 karakter olmalı';
          //   }
          //   return null;RR
          // },
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
            const Text(
              'Araç Özellikleri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Marka', widget.vehicle.brand),
            _buildDetailRow('Model', widget.vehicle.model),
            _buildDetailRow('Yıl', widget.vehicle.year.toString()),
            _buildDetailRow('Kilometre', '${_formatNumber(widget.vehicle.mileage)} km'),
            _buildDetailRow('Yakıt', widget.vehicle.fuelType),
            _buildDetailRow('Vites', widget.vehicle.transmission),
            _buildDetailRow('Motor', widget.vehicle.engineSize),
            _buildDetailRow('Çekiş', widget.vehicle.driveType),
            _buildDetailRow('Renk', widget.vehicle.color),
            _buildDetailRow('Garanti', widget.vehicle.hasWarranty ? 'Var' : 'Yok'),
            _buildDetailRow('Kaza Kaydı', widget.vehicle.hasAccidentRecord ? 'Var' : 'Yok'),
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

