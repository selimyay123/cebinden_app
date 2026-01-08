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
  bool _isInitialized = false;
  final Set<String> _processedPurchaseIds = {};
  
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
    if (_isInitialized) {
      // Zaten başlatılmışsa sadece ürünleri güncelle
      await _loadProducts();
      return;
    }

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

    _isInitialized = true;
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
        await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      } else {
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      purchasePendingNotifier.value = false;
      debugPrint('IAP Buy Error: $e');
      _purchaseEventController.add('error: Satın alma başlatılamadı: $e');
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
          
          // Hata durumunda işlemi MUTLAKA bitir
          if (purchaseDetails.pendingCompletePurchase) {
             try {
               await _inAppPurchase.completePurchase(purchaseDetails);
               debugPrint('IAP: Completed failed transaction to clear queue: ${purchaseDetails.purchaseID}');
             } catch (e) {
               debugPrint('IAP Complete Purchase Error (on error): $e');
             }
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          final String? purchaseID = purchaseDetails.purchaseID;
          
          if (purchaseID == null) {
            debugPrint('IAP: Purchase ID is null, cannot process.');
            try {
               await _inAppPurchase.completePurchase(purchaseDetails);
            } catch (e) { print('Error completing null ID purchase: $e'); }
            continue;
          }

          // 1. IDEMPOTENCY CHECK (Kalıcı Hafıza Kontrolü)
          final bool alreadyProcessed = await _isTransactionProcessed(purchaseID);
          
          if (alreadyProcessed) {
             debugPrint('IAP: Transaction already processed (Persistent): $purchaseID');
             // Zaten işlenmiş, ZORLA kapat.
             try {
               await _inAppPurchase.completePurchase(purchaseDetails);
               debugPrint('IAP: Completed previously processed transaction: $purchaseID');
               _purchaseEventController.add('info: Önceki işlem temizlendi. Lütfen tekrar deneyin.');
             } catch (e) {
               debugPrint('IAP Force Complete Error: $e');
             }
             continue;
          }
          
          // 2. VERIFICATION
          final bool valid = await _verifyPurchase(purchaseDetails);
          
          if (valid) {
            try {
              // 3. DELIVERY (Altın Yükleme)
              await _deliverProduct(purchaseDetails);
              
              // 4. PERSISTENCE (Kalıcı Hafızaya Kaydet)
              await _markTransactionAsProcessed(purchaseID);
              
              // 5. COMPLETE (Apple'a Bildir)
              // pendingCompletePurchase kontrolünü kaldırıyoruz, iOS'ta her zaman deniyoruz.
              try {
                await _inAppPurchase.completePurchase(purchaseDetails);
                debugPrint('IAP: Purchase completed and saved: $purchaseID');
              } catch (e) {
                debugPrint('IAP Final Complete Error: $e');
              }
              
              _purchaseEventController.add('success');
              
            } catch (e) {
              debugPrint('IAP Delivery Error: $e');
              _purchaseEventController.add('error: Teslimat hatası. Lütfen tekrar deneyin.');
            }
          } else {
            debugPrint('IAP Invalid Purchase');
            _purchaseEventController.add('error: Geçersiz satın alma');
            try {
              await _inAppPurchase.completePurchase(purchaseDetails);
            } catch (e) {}
          }
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
            debugPrint('IAP: Purchase Canceled by user or system');
            _purchaseEventController.add('info: İşlem iptal edildi.');
            if (purchaseDetails.pendingCompletePurchase) {
              await _inAppPurchase.completePurchase(purchaseDetails);
            }
        } else {
            debugPrint('IAP: Unhandled status: ${purchaseDetails.status}');
        }
      }
    }
  }

  // Kalıcı hafıza kontrolü
  Future<bool> _isTransactionProcessed(String purchaseID) async {
    final prefs = await SharedPreferences.getInstance();
    final processedList = prefs.getStringList('processed_iap_transactions') ?? [];
    return processedList.contains(purchaseID);
  }

  // Kalıcı hafızaya kaydetme
  Future<void> _markTransactionAsProcessed(String purchaseID) async {
    final prefs = await SharedPreferences.getInstance();
    final processedList = prefs.getStringList('processed_iap_transactions') ?? [];
    processedList.add(purchaseID);
    await prefs.setStringList('processed_iap_transactions', processedList);
    
    // RAM'deki listeyi de güncelle (performans için)
    _processedPurchaseIds.add(purchaseID);
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Gerçek bir backend doğrulaması burada yapılmalı.
    // Şimdilik client-side doğrulama (basitçe true) yapıyoruz.
    return true;
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final user = await _authService.getCurrentUser();
    if (user == null) throw Exception('User not found');

    int goldAmount = 0;
    int bonusAmount = 0;
    
    // Ürün ID'sine göre altın miktarını belirle
    switch (purchaseDetails.productID) {
      case 'altin_01':
        goldAmount = 1;
        bonusAmount = 0;
        break;
      case 'altin_05':
        goldAmount = 5;
        bonusAmount = 1;
        break;
      case 'altin_10':
        goldAmount = 10;
        bonusAmount = 3;
        break;
      case 'altin_25':
        goldAmount = 25;
        bonusAmount = 10;
        break;
      default:
        debugPrint('Unknown product ID: ${purchaseDetails.productID}');
        return;
    }

    if (goldAmount > 0) {
      final totalGoldToAdd = goldAmount + bonusAmount;
      final newGold = user.gold + totalGoldToAdd;
      await _db.updateUser(user.id, {'gold': newGold});
      debugPrint('Gold added: $goldAmount + $bonusAmount Bonus. New total: $newGold');
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
