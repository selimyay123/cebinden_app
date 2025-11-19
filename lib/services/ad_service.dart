import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  /// AdMob'u başlat
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      
    } catch (e) {
      
    }
  }

  /// Reklam yüklenmiş mi?
  bool get isAdReady => _isAdLoaded && _rewardedAd != null;

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

  /// Ödüllü reklam göster
  Future<bool> showRewardedAd({
    required Function(double reward) onRewarded,
    required Function() onAdNotReady,
  }) async {
    if (!isAdReady) {
      
      onAdNotReady();
      return false;
    }

    bool rewardEarned = false;

    _rewardedAd?.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        
        rewardEarned = true;
        // Ödülü ver (1000 TL sabit)
        onRewarded(1000.0);
      },
    );

    return rewardEarned;
  }

  /// Servisi temizle
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
  }
}

