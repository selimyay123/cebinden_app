import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/vehicle_model.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ConfettiController _confettiController;
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: CustomScrollView(
        slivers: [
          // Resim ve AppBar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.deepPurple,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.grey[300],
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Placeholder Resim (Icon)
                    Icon(
                      Icons.directions_car,
                      size: 120,
                      color: Colors.grey[400],
                    ),
                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // İçerik
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık ve Fiyat
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.vehicle.fullName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            widget.vehicle.location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Fiyat',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${_formatCurrency(widget.vehicle.price)} TL',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.deepPurple,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.deepPurple,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'İlan Bilgileri'),
                      Tab(text: 'Açıklama'),
                    ],
                  ),
                ),

                // Tab Content - Dinamik yükseklik
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    return _tabController.index == 0
                        ? _buildSpecificationsTab()
                        : _buildDescriptionTab();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Teklif Ver Butonu
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Teklif Ver özelliği yakında eklenecek'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.deepPurple, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Teklif Ver',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Satın Al Butonu
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentUser != null ? () => _showPurchaseDialog() : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Satın Al',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        ),
        // Confetti Overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.red,
              Colors.yellow,
            ],
            numberOfParticles: 30,
            gravity: 0.3,
          ),
        ),
      ],
    );
  }

  Future<void> _showPurchaseDialog() async {
    if (_currentUser == null) return;

    final currentBalance = _currentUser!.balance;
    final vehiclePrice = widget.vehicle.price;
    final remainingBalance = currentBalance - vehiclePrice;
    final canAfford = remainingBalance >= 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              canAfford ? Icons.info_outline : Icons.warning_amber,
              color: canAfford ? Colors.deepPurple : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Satın Alma Onayı'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sayın ${_currentUser!.username},',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Araç', widget.vehicle.fullName),
              const Divider(),
              _buildInfoRow(
                'Mevcut Bakiyeniz',
                '${_formatCurrency(currentBalance)} ${_currentUser!.currency}',
              ),
              _buildInfoRow(
                'Araç Fiyatı',
                '${_formatCurrency(vehiclePrice)} TL',
                valueColor: Colors.red,
              ),
              const Divider(thickness: 2),
              _buildInfoRow(
                'Kalan Bakiye',
                '${_formatCurrency(remainingBalance)} ${_currentUser!.currency}',
                valueColor: canAfford ? Colors.green : Colors.red,
                isBold: true,
              ),
              if (!canAfford) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Yetersiz bakiye! ${_formatCurrency(vehiclePrice - currentBalance)} ${_currentUser!.currency} eksik.',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Bu işleme devam etmek istediğinizden emin misiniz?',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: canAfford
                ? () {
                    Navigator.pop(context);
                    _processPurchase();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPurchase() async {
    if (_currentUser == null) return;

    try {
      // 1️⃣ Bakiyeyi düş
      final newBalance = _currentUser!.balance - widget.vehicle.price;
      final balanceUpdateSuccess = await _db.updateUser(
        _currentUser!.id,
        {'balance': newBalance},
      );

      if (!balanceUpdateSuccess) {
        throw Exception('Bakiye güncellenemedi');
      }

      // 2️⃣ Aracı kullanıcıya ekle
      final userVehicle = UserVehicle.purchase(
        userId: _currentUser!.id,
        vehicleId: widget.vehicle.id,
        brand: widget.vehicle.brand,
        model: widget.vehicle.model,
        year: widget.vehicle.year,
        mileage: widget.vehicle.mileage,
        purchasePrice: widget.vehicle.price,
        color: widget.vehicle.color,
        fuelType: widget.vehicle.fuelType,
        transmission: widget.vehicle.transmission,
        engineSize: widget.vehicle.engineSize,
        driveType: widget.vehicle.driveType,
        hasWarranty: widget.vehicle.hasWarranty,
        hasAccidentRecord: widget.vehicle.hasAccidentRecord,
        score: widget.vehicle.score, // İlan skoru (Vehicle'dan alınır)
        imageUrl: widget.vehicle.imageUrl,
      );

      final vehicleAddSuccess = await _db.addUserVehicle(userVehicle);

      if (!vehicleAddSuccess) {
        // Bakiyeyi geri yükle
        await _db.updateUser(
          _currentUser!.id,
          {'balance': _currentUser!.balance},
        );
        throw Exception('Araç garajınıza eklenemedi');
      }

      // 3️⃣ Kullanıcıyı güncelle
      await _loadCurrentUser();

      // 4️⃣ Başarılı! Kutlama göster
      _confettiController.play();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başarı ikonu
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'TEBRİKLER! 🎉',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.vehicle.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'başarıyla satın alındı!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.celebration,
                        color: Colors.green,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Artık bu araç sizin!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Yeni bakiyeniz: ${_formatCurrency(newBalance)} TL',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Dialog'u kapat
                    Navigator.pop(context, true); // Detail sayfasından çık ve "satın alma başarılı" bilgisi gönder
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Harika!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      // ❌ Hata durumu
      print('❌ Purchase error: $e');
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Satın Alma Hatası'),
            ],
          ),
          content: Text(
            'Araç satın alınırken bir hata oluştu:\n\n$e\n\nLütfen tekrar deneyin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificationsTab() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'İlan Bilgileri',
            icon: Icons.info_outline,
            children: [
              _buildInfoRow('İlan No', '#${widget.vehicle.id.substring(0, 8).toUpperCase()}'),
              _buildInfoRow('İlan Tarihi', _formatDate(widget.vehicle.listedAt)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Araç Bilgileri',
            icon: Icons.directions_car,
            children: [
              _buildInfoRow('Marka', widget.vehicle.brand),
              _buildInfoRow('Model', widget.vehicle.model),
              _buildInfoRow('Yıl', widget.vehicle.year.toString()),
              _buildInfoRow('Durum', widget.vehicle.condition),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Teknik Özellikler',
            icon: Icons.settings,
            children: [
              _buildInfoRow('Motor Hacmi', '${widget.vehicle.engineSize} L'),
              _buildInfoRow('Yakıt Tipi', widget.vehicle.fuelType),
              _buildInfoRow('Vites', widget.vehicle.transmission),
              _buildInfoRow('Çekiş', widget.vehicle.driveType),
              _buildInfoRow('Kilometre', '${_formatNumber(widget.vehicle.mileage)} km'),
              _buildInfoRow('Renk', widget.vehicle.color),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Durum & Garanti',
            icon: Icons.verified_user,
            children: [
              _buildInfoRow(
                'Garanti Durumu',
                widget.vehicle.hasWarranty ? '✅ Var' : '❌ Yok',
                valueColor: widget.vehicle.hasWarranty ? Colors.green : Colors.red,
              ),
              _buildInfoRow(
                'Ağır Hasar Kaydı',
                widget.vehicle.hasAccidentRecord ? '⚠️ Var' : '✅ Yok',
                valueColor: widget.vehicle.hasAccidentRecord ? Colors.red : Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionTab() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.deepPurple, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Satıcının Notu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.vehicle.description,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu ilan açıklaması eğlence amaçlıdır. Gerçek araç bilgileri için İlan Bilgileri sekmesini kontrol edin! 😄',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
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

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
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

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
  }
}

