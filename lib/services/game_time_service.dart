import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'settings_helper.dart';

/// Oyun içi zaman yönetim servisi
/// 1 oyun günü = 10-15 dakika gerçek zaman (ayarlanabilir)
/// NOT: Zaman sadece uygulama aktifken ilerler
class GameTimeService with WidgetsBindingObserver {
  static final GameTimeService _instance = GameTimeService._internal();
  factory GameTimeService() => _instance;
  GameTimeService._internal();

  // Aktif oyun süresi sistemi
  int _totalPlayedMinutes = 0;      // Toplam aktif oyun süresi
  DateTime? _sessionStartTime;       // Mevcut oturum başlangıcı
  bool _isAppActive = false;         // Uygulama aktif mi?
  
  // Oyun günü değişim notifier
  final ValueNotifier<int> currentGameDay = ValueNotifier<int>(1);
  
  // Oyun saati notifier (0-23 arası)
  final ValueNotifier<int> currentGameHour = ValueNotifier<int>(0);
  
  // Günlük değişim event'i için callback'ler
  final List<Function(int oldDay, int newDay)> _dayChangeCallbacks = [];
  
  // Timer
  Timer? _updateTimer;
  
  // Ayarlar
  int _gameDayDurationMinutes = 5; // Default: 1 oyun günü = 5 dakika
  
  /// Oyun zamanını başlat
  Future<void> initialize() async {
    // Lifecycle observer ekle
    WidgetsBinding.instance.addObserver(this);
    
    // Ayarları yükle
    await _loadSettings();
    
    // Toplam oynanan süreyi yükle
    _totalPlayedMinutes = await SettingsHelper.getTotalPlayedMinutes();
    
    // Mevcut gün ve saati hesapla
    _updateCurrentTime();
    
    // Oturumu başlat
    _startSession();
    
    // Periyodik güncelleme (her dakika) - sadece aktifken çalışır
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isAppActive) {
        _updateCurrentTime();
      }
    });
    

  }
  
  /// Ayarları yükle
  Future<void> _loadSettings() async {
    final duration = await SettingsHelper.getGameDayDuration();
    _gameDayDurationMinutes = duration;
  }
  
  /// Oyun günü süresini değiştir
  Future<void> setGameDayDuration(int minutes) async {
    if (minutes < 2 || minutes > 30) {
      throw Exception('Oyun günü süresi 2-30 dakika arasında olmalıdır');
    }
    
    // Mevcut duruma göre hangi gündeyiz?
    final currentTotalMinutes = getRealMinutesPassed();
    final currentDay = (currentTotalMinutes / _gameDayDurationMinutes).floor() + 1;
    
    // Yeni süreye göre bu günün başlangıcına denk gelen toplam süreyi hesapla
    // Böylece süre değişince günün ortasından değil, başından başlarız (kafa karışıklığını önler)
    final newTotalMinutes = (currentDay - 1) * minutes;
    
    // Aradaki farkı _totalPlayedMinutes'e yansıt
    final diff = newTotalMinutes - currentTotalMinutes;
    _totalPlayedMinutes += diff;
    
    // Değerleri güncelle ve kaydet
    _gameDayDurationMinutes = minutes;
    await SettingsHelper.setGameDayDuration(minutes);
    await SettingsHelper.setTotalPlayedMinutes(_totalPlayedMinutes);
    
    _updateCurrentTime();
  }
  
  /// Mevcut oyun gününü ve saatini güncelle (sadece aktif oyun süresi)
  void _updateCurrentTime() {
    // Şimdiki oturumdaki süreyi ekle
    int currentSessionMinutes = 0;
    if (_sessionStartTime != null && _isAppActive) {
      currentSessionMinutes = DateTime.now().difference(_sessionStartTime!).inMinutes;
    }
    
    // Toplam aktif süre (kaydedilen + mevcut oturum)
    final totalMinutes = _totalPlayedMinutes + currentSessionMinutes;
    
    // Toplam oyun günü geçmiş
    final totalGameDaysPassed = (totalMinutes / _gameDayDurationMinutes).floor();
    final newGameDay = totalGameDaysPassed + 1;
    
    // Oyun saati (0-23 arası)
    final minutesInCurrentDay = totalMinutes % _gameDayDurationMinutes;
    final hourProgress = (minutesInCurrentDay / _gameDayDurationMinutes) * 24;
    final newGameHour = hourProgress.floor();
    
    // Gün değişimi kontrolü
    if (currentGameDay.value != newGameDay) {
      final oldDay = currentGameDay.value;
      currentGameDay.value = newGameDay;
      

      
      // Gün değişim callback'lerini çağır
      for (final callback in _dayChangeCallbacks) {
        callback(oldDay, newGameDay);
      }
    }
    
    // Saat güncelleme
    if (currentGameHour.value != newGameHour) {
      currentGameHour.value = newGameHour;
    }
  }
  
  /// App Lifecycle değişikliklerini dinle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulama açıldı - oturumu başlat

      _startSession();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Uygulama kapandı veya arka plana alındı - oturumu durdur

      _pauseSession();
    }
  }
  
  /// Oyun oturumunu başlat
  void _startSession() {
    if (!_isAppActive) {
      _isAppActive = true;
      _sessionStartTime = DateTime.now();

    }
  }
  
  /// Oyun oturumunu durdur ve kaydet
  void _pauseSession() {
    if (_sessionStartTime != null && _isAppActive) {
      // Bu oturumda geçen süreyi hesapla
      final sessionMinutes = DateTime.now().difference(_sessionStartTime!).inMinutes;
      
      if (sessionMinutes > 0) {
        _totalPlayedMinutes += sessionMinutes;
        
        // Kaydet
        SettingsHelper.setTotalPlayedMinutes(_totalPlayedMinutes);
        

      }
      
      _isAppActive = false;
      _sessionStartTime = null;
    }
  }
  
  /// Gün değişiminde çağrılacak callback ekle
  void addDayChangeListener(Function(int oldDay, int newDay) callback) {
    _dayChangeCallbacks.add(callback);
  }
  
  /// Callback'i kaldır
  void removeDayChangeListener(Function(int oldDay, int newDay) callback) {
    _dayChangeCallbacks.remove(callback);
  }
  
  /// Mevcut oyun gününü al
  int getCurrentDay() => currentGameDay.value;
  
  /// Mevcut oyun saatini al (0-23)
  int getCurrentHour() => currentGameHour.value;
  
  /// Oyun başlangıcından beri geçen toplam aktif dakika
  int getRealMinutesPassed() {
    int currentSessionMinutes = 0;
    if (_sessionStartTime != null && _isAppActive) {
      currentSessionMinutes = DateTime.now().difference(_sessionStartTime!).inMinutes;
    }
    return _totalPlayedMinutes + currentSessionMinutes;
  }
  
  /// Belirli bir gerçek dakika sonrası hangi oyun günü olacak
  int predictGameDay(int realMinutesLater) {
    final totalRealMinutes = getRealMinutesPassed() + realMinutesLater;
    return (totalRealMinutes / _gameDayDurationMinutes).floor() + 1;
  }
  
  /// İki oyun günü arasındaki gerçek dakika farkı
  int realMinutesBetweenDays(int days) {
    return days * _gameDayDurationMinutes;
  }
  
  /// Oyun zamanını formatla (Gün X, Saat Y)
  String getFormattedGameTime() {
    return 'Gün ${currentGameDay.value}, Saat ${currentGameHour.value.toString().padLeft(2, '0')}:00';
  }
  
  /// Oyun günü süresini al
  int getGameDayDuration() => _gameDayDurationMinutes;

  /// Yeni güne kalan süreyi al
  Duration getTimeUntilNextDay() {
    // Toplam geçen dakika (gerçek zaman)
    final totalMinutes = getRealMinutesPassed();
    
    // Şu anki günün başlangıcından beri geçen dakika
    final minutesInCurrentDay = totalMinutes % _gameDayDurationMinutes;
    
    // Kalan dakika
    final remainingMinutes = _gameDayDurationMinutes - minutesInCurrentDay;
    
    // Dakikayı saniyeye çevir (daha hassas olması için session başlangıcına göre saniye hesabı yapılabilir ama şimdilik dakika yeterli)
    // Ancak UI'da saniye saydırmak için daha hassas hesap lazım.
    
    if (_sessionStartTime != null && _isAppActive) {
      // Session başlangıcından beri geçen süre (Duration olarak)
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      
      // Toplam geçen süre (önceki sessionlar + şu anki)
      // _totalPlayedMinutes sadece tam dakikaları tutuyor, bu yüzden hassasiyet kaybı var.
      // Ancak basit bir geri sayım için:
      
      // Kalan süreyi hesapla: (Toplam Gün Süresi - (Toplam Geçen Süre % Toplam Gün Süresi))
      // Bunu dakika cinsinden yapıyoruz.
      
      // Daha hassas hesaplama için:
      // Şu anki dakika içindeki saniyeleri de hesaba katalım.
      final secondsInCurrentMinute = DateTime.now().second;
      
      // Kalan tam dakika
      final remainingFullMinutes = remainingMinutes - 1;
      
      // Kalan saniye
      final remainingSeconds = 60 - secondsInCurrentMinute;
      
      return Duration(minutes: remainingFullMinutes, seconds: remainingSeconds);
    }
    
    return Duration(minutes: remainingMinutes);
  }
  
  /// Servisi temizle
  void dispose() {
    _pauseSession(); // Oturumu kaydet
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    _dayChangeCallbacks.clear();

  }
  
  /// Oyunu sıfırla (yeni oyun için)
  Future<void> resetGameTime() async {
    _pauseSession(); // Mevcut oturumu kaydet
    _totalPlayedMinutes = 0;
    await SettingsHelper.setTotalPlayedMinutes(0);
    currentGameDay.value = 1;
    currentGameHour.value = 0;
    _startSession(); // Yeni oturumu başlat
    _updateCurrentTime();

  }
  
  /// Toplam oyun süresini al (formatlanmış)
  String getTotalPlayTime() {
    final totalMinutes = getRealMinutesPassed();
    final hours = (totalMinutes / 60).floor();
    final minutes = totalMinutes % 60;
    return '$hours saat $minutes dakika';
  }
}

