import 'dart:io';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';

/// Reklam yönetim servisi (Test modunda çalışır)
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  int _adLoadAttempts = 0;
  static const int _maxAdLoadAttempts = 3;

  /// Test Rewarded Ad Unit ID'leri (Google'ın resmi test ID'leri)
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Test ID
    }
    return '';
  }

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  int _interstitialAdLoadAttempts = 0;

  /// Test Interstitial Ad Unit ID'leri
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Test ID
    }
    return '';
  }

  /// AdMob'u başlat
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      // İlk reklamları yükle
      _instance.loadRewardedAd();
      _instance.loadInterstitialAd();
    } catch (e) {
      debugPrint('AdMob init error: $e');
    }
  }

  /// Reklam yüklenmiş mi?
  bool get isAdReady => _isAdLoaded && _rewardedAd != null;
  bool get isInterstitialAdReady => _isInterstitialAdLoaded && _interstitialAd != null;

  /// Ödüllü reklam yükle
  Future<void> loadRewardedAd() async {
    if (_adLoadAttempts >= _maxAdLoadAttempts) {
      return;
    }

    _adLoadAttempts++;

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          _adLoadAttempts = 0;
          _setupAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isAdLoaded = false;
          
          // Yeniden yüklemeyi dene (exponential backoff ile)
          Future.delayed(
            Duration(seconds: _adLoadAttempts * 2),
            () => loadRewardedAd(),
          );
        },
      ),
    );
  }

  /// Geçiş reklamı yükle
  Future<void> loadInterstitialAd() async {
    if (_interstitialAdLoadAttempts >= _maxAdLoadAttempts) {
      return;
    }

    _interstitialAdLoadAttempts++;

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _interstitialAdLoadAttempts = 0;
          _setupInterstitialAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
          
          // Yeniden yüklemeyi dene
          Future.delayed(
            Duration(seconds: _interstitialAdLoadAttempts * 2),
            () => loadInterstitialAd(),
          );
        },
      ),
    );
  }

  /// Reklam callback'lerini ayarla
  void _setupAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        // Bir sonraki reklam için yükle
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadRewardedAd();
      },
    );
  }

  /// Geçiş reklamı callback'lerini ayarla
  void _setupInterstitialAdCallbacks() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdLoaded = false;
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdLoaded = false;
        loadInterstitialAd();
      },
    );
  }

  /// Ödüllü reklam göster
  Future<bool> showRewardedAd({
    Function(double reward)? onRewarded,
    Function()? onAdNotReady,
  }) async {
    if (!isAdReady) {
      if (onAdNotReady != null) onAdNotReady();
      return false;
    }

    final completer = Completer<bool>();
    bool rewardEarned = false;

    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadRewardedAd();
        
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadRewardedAd();
        
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    _rewardedAd?.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        rewardEarned = true;
        // Ödülü ver (1000 TL sabit veya parametre ile)
        if (onRewarded != null) onRewarded(1000.0);
      },
    );

    return completer.future;
  }

  int _saleCount = 0;

  /// Geçiş reklamı göster
  Future<void> showInterstitialAd({bool force = false, bool hasNoAds = false}) async {
    // Eğer kullanıcının reklamları kaldırma özelliği varsa reklam gösterme
    if (hasNoAds) return;

    if (!force) {
      _saleCount++;
      
      // Sadece her 3. satışta reklam göster
      if (_saleCount % 3 != 0) {
        return;
      }
    }

    if (!isInterstitialAdReady) {
      // Reklam hazır değilse yüklemeyi dene
      loadInterstitialAd();
      return;
    }

    _interstitialAd?.show();
  }

  /// Servisi temizle
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdLoaded = false;
  }
}

