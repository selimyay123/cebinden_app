import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../models/user_model.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  
  User? _currentUser;
  bool _isLoading = true;
  int _vehicleCount = 0;
  int _pendingOffersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final user = await _authService.getCurrentUser();
    if (user != null) {
      final vehicles = await _db.getUserVehicles(user.id);
      final pendingOffers = await _db.getPendingOffersCount(user.id);
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          _vehicleCount = vehicles.length;
          _pendingOffersCount = pendingOffers;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('home.statistics'.tr()),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? Center(child: Text('auth.loginRequired'.tr()))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStatCard(
                      icon: Icons.directions_car,
                      label: 'home.totalVehicles'.tr(),
                      value: _vehicleCount.toString(),
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      icon: Icons.local_offer,
                      label: 'home.pendingOffers'.tr(),
                      value: _pendingOffersCount.toString(),
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      icon: Icons.show_chart,
                      label: 'home.totalTransactions'.tr(),
                      value: _vehicleCount.toString(), // Geçici olarak araç sayısı kullanılıyor, home_screen ile aynı
                      color: Colors.green,
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
