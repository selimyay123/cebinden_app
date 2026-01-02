import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../services/game_time_service.dart';
import '../services/database_helper.dart';
import 'home_screen.dart';
import 'brand_selection_screen.dart';
import 'my_vehicles_screen.dart';
import 'my_offers_screen.dart';
import 'settings_screen.dart';
import 'sell_vehicle_screen.dart';
import 'my_listings_screen.dart';
import 'store_screen.dart';
import '../widgets/tab_navigator.dart';
import '../services/screen_refresh_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 3;
  int _pendingOffersCount = 0;
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  StreamSubscription? _offerUpdateSubscription;

  // Navigator keys for each tab to preserve state
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    4: GlobalKey<NavigatorState>(),
    5: GlobalKey<NavigatorState>(),
    6: GlobalKey<NavigatorState>(),
  };

  @override
  void initState() {
    super.initState();
    _checkPendingOffers();
    
    // Teklif güncellemelerini dinle
    _offerUpdateSubscription = _db.onOfferUpdate.listen((_) {
      _checkPendingOffers();
    });

    // Gün değişimini dinle (tekliflerin süresi dolmuş olabilir)
    GameTimeService().currentGameDay.addListener(_checkPendingOffers);
  }

  @override
  void dispose() {
    _offerUpdateSubscription?.cancel();
    GameTimeService().currentGameDay.removeListener(_checkPendingOffers);
    super.dispose();
  }

  Future<void> _checkPendingOffers() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      final count = await _db.getPendingOffersCount(user.id);
      if (mounted) {
        setState(() {
          _pendingOffersCount = count;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sayfaları burada tanımlıyoruz
    final List<Widget> _screens = [
      TabNavigator(
        navigatorKey: _navigatorKeys[0],
        child: BrandSelectionScreen(
          categoryName: 'vehicles.categoryAuto'.tr(),
          categoryColor: Colors.deepPurple,
        ),
      ), // 0: Market
      TabNavigator(
        navigatorKey: _navigatorKeys[1],
        child: const SellVehicleScreen(),
      ),     // 1: Sell
      TabNavigator(
        navigatorKey: _navigatorKeys[2],
        child: const MyVehiclesScreen(),
      ),      // 2: Garage
      const HomeScreen(),            // 3: Home (Center)
      TabNavigator(
        navigatorKey: _navigatorKeys[4],
        child: const MyListingsScreen(),
      ),      // 4: Listings
      TabNavigator(
        navigatorKey: _navigatorKeys[5],
        child: const MyOffersScreen(),
      ), // 5: Offers
      TabNavigator(
        navigatorKey: _navigatorKeys[6],
        child: const StoreScreen(),
      ),           // 6: Store
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
            ScreenRefreshService().notifyTabChanged(index);
            _checkPendingOffers();
          },
          backgroundColor: Colors.white.withOpacity(0.2),
          elevation: 8,
          indicatorColor: Colors.deepPurple.withOpacity(0.2),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: [
            // Market
            NavigationDestination(
              icon: const Icon(Icons.search),
              selectedIcon: const Icon(Icons.search, color: Colors.deepPurple),
              label: 'market.title'.tr(),
            ),
            // Sell
            NavigationDestination(
              icon: const Icon(Icons.sell_outlined),
              selectedIcon: const Icon(Icons.sell, color: Colors.deepPurple),
              label: 'home.sellVehicle'.tr(),
            ),
            // Garage
            NavigationDestination(
              icon: const Icon(Icons.directions_car_outlined),
              selectedIcon: const Icon(Icons.directions_car, color: Colors.deepPurple),
              label: 'garage.title'.tr(),
            ),
            // Home
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard, color: Colors.deepPurple),
              label: 'home.title'.tr(),
            ),
            // Listings
            NavigationDestination(
              icon: const Icon(Icons.list_alt_outlined),
              selectedIcon: const Icon(Icons.list_alt, color: Colors.deepPurple),
              label: 'home.myListings'.tr(),
            ),
            // Offers
            NavigationDestination(
              icon: _pendingOffersCount > 0
                  ? Badge(
                      label: Text('$_pendingOffersCount'),
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.handshake_outlined),
                    )
                  : const Icon(Icons.handshake_outlined),
              selectedIcon: _pendingOffersCount > 0
                  ? Badge(
                      label: Text('$_pendingOffersCount'),
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.handshake, color: Colors.deepPurple),
                    )
                  : const Icon(Icons.handshake, color: Colors.deepPurple),
              label: 'offers.title'.tr(),
            ),
            // Store
            NavigationDestination(
              icon: const Icon(Icons.shopping_bag_outlined),
              selectedIcon: const Icon(Icons.shopping_bag, color: Colors.deepPurple),
              label: 'store.title'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
