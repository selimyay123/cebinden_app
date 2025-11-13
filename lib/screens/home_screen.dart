import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import 'login_screen.dart';
import 'vehicle_category_screen.dart';
import 'settings_screen.dart';
import 'my_vehicles_screen.dart';
import 'sell_vehicle_screen.dart';
import 'my_listings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  User? _currentUser;
  bool _isLoading = true;
  int _vehicleCount = 0;
  List<UserVehicle> _userVehicles = [];
  List<UserVehicle> _userListedVehicles = []; // Satışa çıkarılan araçlar

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    
    // Eski kullanıcıların bakiyesini güncelle (özel bonus! 🎁)
    // 1,000,000'dan az olan tüm kullanıcılar → 5,000,000 TL
    if (user != null && user.balance < 1000000.0) {
      await _db.updateUser(user.id, {'balance': 5000000.0});
      // Güncellenmiş kullanıcıyı tekrar yükle
      final updatedUser = await _authService.getCurrentUser();
      
      // Kullanıcının araçlarını yükle
      final vehicles = await _db.getUserActiveVehicles(updatedUser!.id);
      final vehicleCount = vehicles.length;
      
      // Kullanıcının satışa çıkardığı araçları yükle
      final listedVehicles = await _db.getUserListedVehicles(updatedUser.id);
      
      setState(() {
        _currentUser = updatedUser;
        _userVehicles = vehicles;
        _vehicleCount = vehicleCount;
        _userListedVehicles = listedVehicles;
        _isLoading = false;
      });
      
      // Kullanıcıya bilgi ver
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Özel bonus! Bakiyeniz 5,000,000 TL\'ye yükseltildi!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      // Kullanıcının araçlarını yükle
      if (user != null) {
        final vehicles = await _db.getUserActiveVehicles(user.id);
        final vehicleCount = vehicles.length;
        
        // Kullanıcının satışa çıkardığı araçları yükle
        final listedVehicles = await _db.getUserListedVehicles(user.id);
        
        setState(() {
          _currentUser = user;
          _userVehicles = vehicles;
          _vehicleCount = vehicleCount;
          _userListedVehicles = listedVehicles;
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    // Onay dialogu göster
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Çıkış yap
      await _authService.logout();
      
      if (!mounted) return;
      
      // Giriş ekranına yönlendir
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Bildirimler',
            onPressed: () {
              // TODO: Bildirimler sayfası
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadCurrentUser,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Profil ve Bakiye Kartı
                    _buildProfileCard(),
                    
                    const SizedBox(height: 16),
                    
                    // Hızlı İşlemler
                    _buildQuickActions(),
                    
                    const SizedBox(height: 16),
                    
                    // Galeri Satın Al
                    _buildBuyGalleryButton(),
                    
                    const SizedBox(height: 16),
                    
                    // İstatistikler
                    _buildStatistics(),
                    
                    const SizedBox(height: 16),
                    
                    // Araçlarım (YORUM: Garaj özelliği için ayrı sayfa yapıldı)
                    // _buildMyVehicles(),
                    // const SizedBox(height: 16),
                    
                    // İlanlarım (YORUM: Quick actions'a taşındı)
                    // if (_userListedVehicles.isNotEmpty) ...[
                    //   _buildMyListings(),
                    //   const SizedBox(height: 16),
                    // ],
                    
                    // Son İşlemler veya Bilgilendirme
                    _buildRecentActivity(),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // Profil ve Bakiye Kartı
  Widget _buildProfileCard() {
    if (_currentUser == null) return const SizedBox.shrink();
    
    final isProfit = _currentUser!.profitLossPercentage >= 0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.deepPurple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profil Resmi
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                _currentUser!.username[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Kullanıcı Bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kullanıcı Adı
                Text(
                  _currentUser!.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Toplam Para
                Text(
                  'Toplam Bakiye',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatCurrency(_currentUser!.balance)} TL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Kar/Zarar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isProfit 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isProfit ? Colors.green : Colors.red,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isProfit 
                            ? Icons.trending_up 
                            : Icons.trending_down,
                        color: isProfit ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${isProfit ? '+' : ''}${_currentUser!.profitLossPercentage.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: isProfit ? Colors.green : Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Hızlı İşlemler
  Widget _buildQuickActions() {
    // Hızlı işlem butonları listesi - Yeni özellik eklemek için buraya ekleyin
    final quickActions = [
      {
        'icon': Icons.shopping_cart,
        'label': 'Araç Al',
        'color': Colors.blue,
        'onTap': () async {
          // Kategori seçim sayfasına git ve satın alma sonucunu bekle
          final purchased = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VehicleCategoryScreen(),
            ),
          );
          
          // Eğer satın alma başarılıysa, dashboard'u yenile
          if (purchased == true) {
            await _loadCurrentUser();
          }
        },
      },
      {
        'icon': Icons.sell,
        'label': 'Araç Sat',
        'color': Colors.orange,
        'onTap': () async {
          // Araç satış sayfasına git ve sonuç bekle
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SellVehicleScreen(),
            ),
          );
          
          // Eğer işlem başarılıysa, dashboard'u yenile
          if (result == true) {
            await _loadCurrentUser();
          }
        },
      },
      {
        'icon': Icons.garage,
        'label': 'Araçlarım',
        'color': Colors.green,
        'onTap': () {
          // Kullanıcının satın aldığı araçları göster
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyVehiclesScreen(),
            ),
          );
        },
      },
      {
        'icon': Icons.store,
        'label': 'İlanlarım',
        'color': Colors.purple,
        'onTap': () async {
          // İlanlar sayfasına git
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyListingsScreen(),
            ),
          );
          // Sayfa kapanınca dashboard'u yenile (ilan kaldırılmış olabilir)
          await _loadCurrentUser();
        },
      },
      // {
      //   'icon': Icons.car_rental,
      //   'label': 'Araç Kirala',
      //   'color': Colors.purple,
      //   'onTap': () {
      //     // TODO: Araç kiralama sayfası
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(
      //         content: Text('Araç kiralama sayfası yakında...'),
      //         duration: Duration(seconds: 2),
      //       ),
      //     );
      //   },
      // },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 sütun
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3, // Buton yükseklik/genişlik oranı
        ),
        itemCount: quickActions.length,
        itemBuilder: (context, index) {
          final action = quickActions[index];
          return _buildActionButton(
            icon: action['icon'] as IconData,
            label: action['label'] as String,
            color: action['color'] as Color,
            onTap: action['onTap'] as VoidCallback,
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // İstatistikler
  Widget _buildStatistics() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İstatistikler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // YORUM: Galeri istatistiği - İleride farklı kurgu için ayrılmış
              // Expanded(
              //   child: _buildStatItem(
              //     icon: Icons.garage,
              //     label: 'Galerim',
              //     value: _vehicleCount.toString(),
              //     color: Colors.blue,
              //   ),
              // ),
              // const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.directions_car,
                  label: 'Toplam Araç',
                  value: _vehicleCount.toString(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.show_chart,
                  label: 'Toplam İşlem',
                  value: _vehicleCount.toString(),
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // YORUM: Garaj/Galeri Özelliği - İleride farklı kurgu için ayrılmış
  // Şimdilik "Araçlarım" butonu direkt MyVehiclesScreen sayfasına gidiyor
  // ============================================================================
  
  /*
  // Kullanıcının Araçları (Dashboard'da özet gösterim)
  Widget _buildMyVehicles() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.garage, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text(
                    'Garajım',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              if (_vehicleCount > 0)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyVehiclesScreen(),
                      ),
                    );
                  },
                  child: const Text('Tümünü Gör'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Araç listesi
          if (_vehicleCount == 0)
            // Hiç araç yok
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz aracınız yok',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İlk aracınızı satın alarak garajınızı oluşturun!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final purchased = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VehicleCategoryScreen(),
                        ),
                      );
                      if (purchased == true) {
                        await _loadCurrentUser();
                      }
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Araç Satın Al'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Araçları göster (maksimum 3 tane)
            Column(
              children: _userVehicles.take(3).map((vehicle) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.directions_car,
                          color: Colors.deepPurple,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.fullName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${vehicle.year} • ${_formatNumber(vehicle.mileage)} km',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Satın alma: ${_formatCurrency(vehicle.purchasePrice)} TL',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                          const SizedBox(height: 4),
                          Text(
                            '${vehicle.daysOwned}g',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          
          if (_vehicleCount > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${_vehicleCount - 3} araç daha...',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
  */

  // Galeri Satın Al Butonu
  Widget _buildBuyGalleryButton() {
    const galleryPrice = 10000000.0; // 10 Milyon TL

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showGalleryInfoDialog(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade500],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Sol taraf - İkon ve Başlık
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.store_mall_directory,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Galeri Satın Al',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Profesyonel İşletme',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Sağ taraf - Fiyat
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_formatCurrency(galleryPrice)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'TL',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Galeri Bilgilendirme Dialog'u
  void _showGalleryInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.store_mall_directory,
                color: Colors.green,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Galeri Sahibi Olun',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Galeri satın alarak işletmenizi profesyonel seviyeye taşıyın ve yeni gelir kapıları açın.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              
              // Avantajlar
              const Text(
                'Galeri Avantajları',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.car_rental,
                title: 'Araç Kiralama Hizmeti',
                description: 'Garajınızdaki araçları kiralayarak pasif gelir elde edin.',
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.trending_down,
                title: 'Fırsat Alımları',
                description: 'Acil nakit ihtiyacı olan müşterilerden piyasa değerinin altında araç satın alın.',
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.trending_up,
                title: 'Yüksek Kar Marjı',
                description: 'Profesyonel galeri olarak araçlarınızı daha yüksek fiyatlarla satın.',
              ),
              const SizedBox(height: 12),
              
              _buildAdvantageItem(
                icon: Icons.workspace_premium,
                title: 'Prestij & İtibar',
                description: 'Galeri statüsü ile daha fazla müşteri ve güven kazanın.',
              ),
              
              const SizedBox(height: 20),
              
              // Fiyat Bilgisi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Galeri Fiyatı:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${_formatCurrency(10000000.0)} TL',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // İptal Butonu
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'İptal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Devam Et Butonu
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Galeri satın alma işlemi
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Galeri satın alma özelliği yakında aktif olacak!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Devam Et',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Avantaj Item Widget
  Widget _buildAdvantageItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.green,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Son Aktivite / Bilgilendirme
  Widget _buildRecentActivity() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                'Hoş Geldiniz!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Araç alım satım platformumuza hoş geldiniz! Başlamak için yukarıdaki hızlı işlemler menüsünden bir seçim yapabilirsiniz.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          if (_currentUser != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Üyelik: ${_formatDate(_currentUser!.registeredAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // İlanlarım (Satışa çıkarılan araçlar)
  Widget _buildMyListings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.store, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text(
                      'İlanlarım',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_userListedVehicles.length} İlan',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // İlan listesi
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _userListedVehicles.length > 3 ? 3 : _userListedVehicles.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final vehicle = _userListedVehicles[index];
              return _buildListingCard(vehicle);
            },
          ),
          
          // Tümünü gör butonu (eğer 3'ten fazla ilan varsa)
          if (_userListedVehicles.length > 3)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () {
                  // TODO: Tüm ilanları göster
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tüm ilanlarınızı görüntülemek için yakında...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text('Tüm İlanları Gör (${_userListedVehicles.length})'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // İlan kartı
  Widget _buildListingCard(UserVehicle vehicle) {
    return InkWell(
      onTap: () {
        // TODO: İlan detay sayfasına git
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İlan detay sayfası yakında...'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Araç ikonu
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_car,
                color: Colors.green,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            
            // Araç bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vehicle.year} • ${_formatNumber(vehicle.mileage)} km',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatCurrency(vehicle.listingPrice ?? 0)} TL',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            
            // Tarih ve durum
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Aktif',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${vehicle.daysOwned} gün',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Para formatı
  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // Sayı formatı (1000 → 1.000)
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // Drawer (Yan Menü)
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 50,
                bottom: 30,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.deepPurple.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profil Resmi
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      child: _currentUser != null
                          ? Text(
                              _currentUser!.username[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                              ),
                            )
                          : const Icon(Icons.person, size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Kullanıcı Adı
                  if (_currentUser != null) ...[
                    Text(
                      _currentUser!.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCurrency(_currentUser!.balance)} TL',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Menü Öğeleri
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    onTap: () {
                      Navigator.pop(context); // Drawer'ı kapat
                      // Zaten dashboard'dayız, bir şey yapmaya gerek yok
                    },
                    isSelected: true, // Dashboard seçili
                  ),
                  _buildDrawerItem(
                    icon: Icons.shopping_cart,
                    title: 'Araç Satın Al',
                    onTap: () async {
                      Navigator.pop(context); // Drawer'ı kapat
                      // Kategori seçim sayfasına git ve satın alma sonucunu bekle
                      final purchased = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VehicleCategoryScreen(),
                        ),
                      );
                      
                      // Eğer satın alma başarılıysa, dashboard'u yenile
                      if (purchased == true) {
                        await _loadCurrentUser();
                      }
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.sell,
                    title: 'Araç Sat',
                    onTap: () async {
                      Navigator.pop(context); // Drawer'ı kapat
                      // Araç satış sayfasına git
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SellVehicleScreen(),
                        ),
                      );
                      
                      // Eğer işlem başarılıysa, dashboard'u yenile
                      if (result == true) {
                        await _loadCurrentUser();
                      }
                    },
                  ),
                  // _buildDrawerItem(
                  //   icon: Icons.car_rental,
                  //   title: 'Araç Kirala',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     // TODO: Araç kiralama sayfasına git
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       const SnackBar(
                  //         content: Text('Araç kiralama sayfası yakında...'),
                  //         duration: Duration(seconds: 2),
                  //       ),
                  //     );
                  //   },
                  // ),
                  _buildDrawerItem(
                    icon: Icons.task_alt,
                    title: 'Görevler',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Görevler sayfasına git
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Görevler sayfası yakında...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
            
            // Ayarlar (En Altta)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: _buildDrawerItem(
                icon: Icons.settings,
                title: 'Ayarlar',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Drawer Menü Öğesi
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.deepPurple : Colors.grey[700],
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.deepPurple : Colors.grey[800],
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.deepPurple.withOpacity(0.1),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 4,
      ),
    );
  }
}

