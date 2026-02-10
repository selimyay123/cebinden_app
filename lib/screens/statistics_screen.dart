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
  
  // Garage Stats
  int _totalVehicles = 0;
  double _garageValue = 0;
  String _mostExpensiveCarName = "-";
  double _mostExpensiveCarPrice = 0;

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
      
      // Calculate stats
      double totalValue = 0;
      double maxPrice = 0;
      String maxPriceName = "-";
      
      for (var vehicle in vehicles) {
        // Assuming purchasePrice is available or we use price
        // If purchasePrice is not available in UserVehicle, we might need to fetch it or use current price
        // For now, let's assume we use the price field which represents current value or purchase price
        double price = vehicle.purchasePrice; 
        totalValue += price;
        
        if (price > maxPrice) {
          maxPrice = price;
          maxPriceName = "${vehicle.brand} ${vehicle.model}";
        }
      }
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          _totalVehicles = vehicles.length;
          _garageValue = totalValue;
          _mostExpensiveCarPrice = maxPrice;
          _mostExpensiveCarName = maxPriceName;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'home.statistics'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurpleAccent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/general_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _currentUser == null
                ? Center(child: Text('auth.loginRequired'.tr(), style: const TextStyle(color: Colors.white)))
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          // Garage Stats Section
                          _buildSectionTitle('home.myVehicles'.tr()), // Using 'My Vehicles' as title for Garage section
                          const SizedBox(height: 16),
                          
                          _buildStatItem(
                            'home.totalVehicles'.tr(),
                            _totalVehicles.toString(),
                          ),
                          const SizedBox(height: 12),
                          
                          _buildStatItem(
                            'stats.garage_value'.tr(),
                            _formatCurrency(_garageValue),
                          ),
                          const SizedBox(height: 12),
                          
                          _buildStatItem(
                            'stats.most_expensive'.tr(),
                            _mostExpensiveCarName,
                            subValue: _mostExpensiveCarPrice > 0 ? _formatCurrency(_mostExpensiveCarPrice) : null,
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {String? subValue}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subValue != null)
                Text(
                  subValue,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
