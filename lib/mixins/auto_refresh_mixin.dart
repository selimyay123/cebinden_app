import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/route_observer.dart';
import '../services/screen_refresh_service.dart';

/// Ekranın görünür olduğunda otomatik yenilenmesini sağlayan mixin.
/// 
/// Kullanım:
/// 1. State class'ına `with RouteAware, AutoRefreshMixin` ekleyin.
/// 2. `refresh()` metodunu override edin ve veri yükleme işlemini yapın.
/// 3. `tabIndex` getter'ını override edin ve bu ekranın tab index'ini döndürün (Eğer tab içindeyse).
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> implements RouteAware {
  StreamSubscription? _tabSubscription;

  /// Bu ekranın tab index'i. Eğer tab yapısında değilse null dönebilir.
  int? get tabIndex => null;

  /// Verileri yenilemek için çağrılacak metod.
  void refresh();

  @override
  void initState() {
    super.initState();
    // Tab değişikliklerini dinle
    if (tabIndex != null) {
      _tabSubscription = ScreenRefreshService().onTabChanged.listen((index) {
        if (index == tabIndex && mounted) {
          refresh();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RouteObserver'a abone ol
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabSubscription?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Başka bir ekrandan geri dönüldüğünde (örn: detay sayfasından)
    refresh();
  }

  @override
  void didPush() {
    // Ekran ilk açıldığında (zaten initState'de yükleniyor olabilir ama emin olmak için)
    // Genelde initState yeterlidir, burayı boş bırakabiliriz veya opsiyonel yapabiliriz.
  }

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
