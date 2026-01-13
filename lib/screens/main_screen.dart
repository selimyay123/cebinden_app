import 'dart:async';
import 'package:flutter/services.dart';
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
  StreamSubscription? _tabChangeSubscription;

  // Navigator keys for each tab to preserve state
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    4: GlobalKey<NavigatorState>(),
    5: GlobalKey<NavigatorState>(),
    6: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(), // Home tab navigator key
  };

  // Tutorial Keys
  final GlobalKey _marketTabKey = GlobalKey();
  final GlobalKey _sellTabKey = GlobalKey();
  final GlobalKey _garageTabKey = GlobalKey();
  final GlobalKey _listingsTabKey = GlobalKey();
  final GlobalKey _offersTabKey = GlobalKey();
  final GlobalKey _storeTabKey = GlobalKey();
  final GlobalKey<ScaffoldState> _mainScaffoldKey = GlobalKey<ScaffoldState>();

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
    
    // Tab değişim isteklerini dinle
    _tabChangeSubscription = ScreenRefreshService().onTabChangeRequested.listen((index) {
      if (mounted) {
        // Eğer Dashboard (Home) seçildiyse ve zaten oradaysak veya başka tabdan geliyorsak
        // Her durumda Dashboard'un stack'ini sıfırla
        if (index == 3) {
          _navigatorKeys[3]?.currentState?.popUntil((route) => route.isFirst);
        }

        setState(() {
          _currentIndex = index;
        });
        // notifyTabChanged çağırmaya gerek yok, çünkü bu zaten bir istek sonucu oldu
        // ama tutarlılık için çağrılabilir, şimdilik gerek yok
      }
    });
  }

  @override
  void dispose() {
    _offerUpdateSubscription?.cancel();
    _tabChangeSubscription?.cancel();
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
      TabNavigator(
        navigatorKey: _navigatorKeys[3],
        child: HomeScreen(
          marketTabKey: _marketTabKey,
          sellTabKey: _sellTabKey,
          garageTabKey: _garageTabKey,
          listingsTabKey: _listingsTabKey,
          offersTabKey: _offersTabKey,
          storeTabKey: _storeTabKey,
          mainScaffoldKey: _mainScaffoldKey,
        ),
      ),            // 3: Home (Center)
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final NavigatorState? currentNavigator =
            _navigatorKeys[_currentIndex]?.currentState;

        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else if (_currentIndex != 3) {
          // Eğer ana sayfada değilsek, ana sayfaya dön
          setState(() {
            _currentIndex = 3;
          });
          ScreenRefreshService().notifyTabChanged(3);
          _checkPendingOffers();
        } else {
          // Ana sayfadaysak ve geri gidilecek yer yoksa uygulamadan çıkılabilir
          // SystemNavigator.pop() kullanılabilir veya kullanıcıya sorulabilir
          // Şimdilik sistemin çıkış yapmasına izin veriyoruz (canPop: false olduğu için manuel çıkış lazım)
          // Ancak kullanıcı deneyimi için genellikle ana sayfada tekrar basınca çıkış istenir.
          // Burada direkt çıkış yapalım:
          // SystemNavigator.pop(); // Bu import gerektirir: import 'package:flutter/services.dart';
          // Veya basitçe:
          // exit(0); // import 'dart:io';
          
          // Ancak Flutter'da best practice, PopScope'un canPop'unu true yapıp tekrar pop çağırmaktır
          // ama burada logic karmaşıklaşabilir. 
          // En temiz yöntem:
          // SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          
          // Şimdilik kullanıcı "swipe back" yaptığında app kapansın istiyorsa (root'ta)
          // bu davranışı simüle edelim.
          // Ama "swipe back" ile kapanması "bug" olarak nitelendirildiğine göre,
          // muhtemelen *yanlışlıkla* kapanmasını istemiyorlar.
          // Yine de root'ta ise kapanması normaldir.
          // Bizim amacımız *nested* iken kapanmaması.
          
          // Eğer buraya düştüysek: Tab'ın rootundayız VE Home tabındayız.
          // Bu durumda app kapanmalı.
           SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _mainScaffoldKey,
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
              // Eğer Dashboard (Home) veya Market seçildiyse stack'i sıfırla
              if (index == 3) {
                _navigatorKeys[3]?.currentState?.popUntil((route) => route.isFirst);
              } else if (index == 0) {
                _navigatorKeys[0]?.currentState?.popUntil((route) => route.isFirst);
              }

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
                icon: Icon(Icons.search, key: _marketTabKey),
                selectedIcon: const Icon(Icons.search, color: Colors.deepPurple),
                label: 'market.title'.tr(),
              ),
              // Sell
              NavigationDestination(
                icon: Icon(Icons.sell_outlined, key: _sellTabKey),
                selectedIcon: const Icon(Icons.sell, color: Colors.deepPurple),
                label: 'home.sellVehicle'.tr(),
              ),
              // Garage
              NavigationDestination(
                icon: Icon(Icons.directions_car_outlined, key: _garageTabKey),
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
                icon: Icon(Icons.list_alt_outlined, key: _listingsTabKey),
                selectedIcon: const Icon(Icons.list_alt, color: Colors.deepPurple),
                label: 'home.myListings'.tr(),
              ),
              // Offers
              NavigationDestination(
                icon: _pendingOffersCount > 0
                    ? Badge(
                        label: Text('$_pendingOffersCount'),
                        backgroundColor: Colors.red,
                        child: Icon(Icons.handshake_outlined, key: _offersTabKey),
                      )
                    : Icon(Icons.handshake_outlined, key: _offersTabKey),
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
                icon: Icon(Icons.shopping_bag_outlined, key: _storeTabKey),
                selectedIcon: const Icon(Icons.shopping_bag, color: Colors.deepPurple),
                label: 'store.title'.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
