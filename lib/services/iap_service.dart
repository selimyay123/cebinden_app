import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();

  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final List<String> _productIds = ['altin_01', 'altin_05', 'altin_10', 'altin_25'];
  
  // Ürünleri ve satın alma durumunu dışarıya açmak için
  final ValueNotifier<List<ProductDetails>> productsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> isAvailableNotifier = ValueNotifier(false);
  final ValueNotifier<bool> purchasePendingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);
  
  final StreamController<String> _purchaseEventController = StreamController<String>.broadcast();
  Stream<String> get purchaseEvents => _purchaseEventController.stream;

  factory IAPService() {
    return _instance;
  }

  IAPService._internal();

  Future<void> initialize() async {
    errorNotifier.value = null;
    final bool isAvailable = await _inAppPurchase.isAvailable();
    isAvailableNotifier.value = isAvailable;

    if (!isAvailable) {
      debugPrint('IAP Service not available');
      errorNotifier.value = 'Mağaza bağlantısı kurulamadı (Servis kullanılamıyor)';
      return;
    }

    // Satın alma dinleyicisini başlat
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdated,
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        debugPrint('IAP Error: $error');
        errorNotifier.value = 'Satın alma servisi hatası: $error';
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds.toSet());

      if (response.error != null) {
        debugPrint('IAP Product Fetch Error: ${response.error}');
        errorNotifier.value = 'Ürünler yüklenirken hata oluştu: ${response.error?.message}';
        return;
      }

      if (response.productDetails.isEmpty) {
        debugPrint('IAP No products found');
        errorNotifier.value = 'Satılacak ürün bulunamadı. Lütfen mağaza ayarlarını kontrol edin.';
        return;
      }

      // Ürünleri fiyata göre sırala
      final List<ProductDetails> sortedProducts = List.from(response.productDetails);
      sortedProducts.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      
      productsNotifier.value = sortedProducts;
      errorNotifier.value = null; // Hata yok
    } catch (e) {
      debugPrint('IAP Exception: $e');
      errorNotifier.value = 'Beklenmedik bir hata oluştu: $e';
    }
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    purchasePendingNotifier.value = true;
    
    try {
      if (_productIds.contains(product.id)) {
        // Consumable (Tüketilebilir) ürün olarak al
        await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      } else {
        // Non-consumable (Kalıcı) ürün
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      purchasePendingNotifier.value = false;
      debugPrint('IAP Buy Error: $e');
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        purchasePendingNotifier.value = true;
      } else {
        purchasePendingNotifier.value = false;
        
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('IAP Purchase Error: ${purchaseDetails.error}');
          _purchaseEventController.add('error: ${purchaseDetails.error?.message ?? "Bir hata oluştu"}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await _deliverProduct(purchaseDetails);
            _purchaseEventController.add('success');
          } else {
            debugPrint('IAP Invalid Purchase');
            _purchaseEventController.add('error: Geçersiz satın alma');
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Gerçek bir backend doğrulaması burada yapılmalı.
    // Şimdilik client-side doğrulama (basitçe true) yapıyoruz.
    return true;
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final user = await _authService.getCurrentUser();
    if (user == null) return;

    int goldAmount = 0;
    
    // Ürün ID'sine göre altın miktarını belirle
    switch (purchaseDetails.productID) {
      case 'altin_01':
        goldAmount = 1;
        break;
      case 'altin_05':
        goldAmount = 5;
        break;
      case 'altin_10':
        goldAmount = 10;
        break;
      case 'altin_25':
        goldAmount = 25;
        break;
      default:
        debugPrint('Unknown product ID: ${purchaseDetails.productID}');
        return;
    }

    if (goldAmount > 0) {
      final newGold = user.gold + goldAmount;
      await _db.updateUser(user.id, {'gold': newGold});
      debugPrint('Gold added: $goldAmount. New total: $newGold');
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
