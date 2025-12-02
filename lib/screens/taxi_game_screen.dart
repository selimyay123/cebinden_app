import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';
import '../services/localization_service.dart';
import '../services/ad_service.dart'; // AdService eklendi

class TaxiGameScreen extends StatefulWidget {
  const TaxiGameScreen({super.key});

  @override
  State<TaxiGameScreen> createState() => _TaxiGameScreenState();
}

class _TaxiGameScreenState extends State<TaxiGameScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final AdService _adService = AdService(); // AdService instance
  
  // Oyun Ayarları
  static const int laneCount = 3;
  static const double laneWidth = 80.0;
  static const double playerHeight = 60.0;
  static const double obstacleHeight = 60.0;
  static const int baseRewardPerCar = 50;
  
  // Oyun Durumu
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0; // Geçilen araç sayısı
  int _moneyEarned = 0;
  int _playerLane = 1; // 0: Sol, 1: Orta, 2: Sağ
  double _gameSpeed = 5.0; // Piksel/tick
  Timer? _gameLoop;
  
  // Engeller
  final List<Obstacle> _obstacles = [];
  double _distanceTraveled = 0;
  double _nextSpawnDistance = 200;

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }

  void _startGame() {
    // Oyun başlarken reklam yükle
    _adService.loadRewardedAd();

    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _moneyEarned = 0;
      _playerLane = 1;
      _gameSpeed = 5.0;
      _obstacles.clear();
      _distanceTraveled = 0;
      _nextSpawnDistance = 200;
    });

    _gameLoop = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      _updateGame();
    });
  }

  void _updateGame() {
    if (!_isPlaying || _isGameOver) return;

    setState(() {
      // Hızlandırma (her 1000 pikselde bir)
      if (_distanceTraveled % 1000 < _gameSpeed) {
        _gameSpeed += 0.1;
      }
      
      _distanceTraveled += _gameSpeed;

      // Engel Oluşturma
      if (_distanceTraveled >= _nextSpawnDistance) {
        _spawnObstacle();
        // Bir sonraki engel için mesafe (hız arttıkça azalabilir veya rastgele olabilir)
        _nextSpawnDistance = _distanceTraveled + 300 + Random().nextInt(200);
      }

      // Engelleri Hareket Ettir
      for (var i = _obstacles.length - 1; i >= 0; i--) {
        _obstacles[i].y += _gameSpeed;

        // Ekrandan çıktı mı?
        if (_obstacles[i].y > MediaQuery.of(context).size.height) {
          _obstacles.removeAt(i);
          _score++;
          _moneyEarned += baseRewardPerCar;
        }
        
        // Çarpışma Kontrolü
        // Basit AABB çarpışma
        // Oyuncu Y pozisyonu: Ekranın altından biraz yukarıda sabit
        final playerY = MediaQuery.of(context).size.height - 150; 
        
        if (_obstacles[i].lane == _playerLane &&
            _obstacles[i].y + obstacleHeight > playerY &&
            _obstacles[i].y < playerY + playerHeight) {
          _gameOver();
        }
      }
    });
  }

  void _spawnObstacle() {
    // Rastgele şerit, ama oyuncunun olduğu şerit olmasın (ilk başlarda kolaylık olsun diye)
    // İleride zorluk artınca her yere çıkabilir.
    int lane = Random().nextInt(laneCount);
    _obstacles.add(Obstacle(lane: lane, y: -100));
  }

  void _moveLeft() {
    if (_playerLane > 0) {
      setState(() => _playerLane--);
    }
  }

  void _moveRight() {
    if (_playerLane < laneCount - 1) {
      setState(() => _playerLane++);
    }
  }

  Future<void> _gameOver() async {
    _gameLoop?.cancel();
    setState(() {
      _isGameOver = true;
      _isPlaying = false;
    });

    // Ödülü ver
    if (_moneyEarned > 0) {
      final userMap = await _db.getCurrentUser();
      if (userMap != null) {
        final user = User.fromJson(userMap);
        await _db.updateUser(user.id, {
          'balance': user.balance + _moneyEarned,
        });
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            bool isAdWatched = false;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.flag, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text('Yolculuk Bitti'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // const Icon(Icons.car_crash, color: Colors.red, size: 64),
                  // const SizedBox(height: 16),
                  Text(
                    'Toplam Kazanç:',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    '$_moneyEarned TL',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  if (isAdWatched)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '2x KAZANÇ AKTİF!',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Geçilen Araç: $_score', style: const TextStyle(fontSize: 16)),
                ],
              ),
              actions: [
                if (!isAdWatched && _moneyEarned > 0)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Reklam izle
                        await _adService.showRewardedAd(
                          onRewarded: (reward) async {
                            // Ödülü ikiye katla (ekstra bir kez daha ekle)
                            final userMap = await _db.getCurrentUser();
                            if (userMap != null) {
                              final user = User.fromJson(userMap);
                              await _db.updateUser(user.id, {
                                'balance': user.balance + _moneyEarned, // Zaten bir kere eklenmişti, bir daha ekle
                              });
                            }
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tebrikler! Kazancınız ikiye katlandı!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              
                              // Dialog'u kapat
                              Navigator.pop(context);
                              // Ekranı kapat (Ana sayfaya dön)
                              Navigator.pop(context);
                            }
                          },
                          onAdNotReady: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reklam şu an hazır değil, lütfen tekrar deneyin.')),
                            );
                            _adService.loadRewardedAd(); // Tekrar yüklemeyi dene
                          },
                        );
                      },
                      icon: const Icon(Icons.play_circle_filled),
                      label: const Text('2x Kazanç (Reklam İzle)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Dialog kapat
                        Navigator.pop(context); // Ekranı kapat
                      },
                      child: const Text('Çıkış'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _startGame();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      child: const Text('Tekrar Oyna'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final roadWidth = laneCount * laneWidth;
    final roadX = (screenWidth - roadWidth) / 2;

    return Scaffold(
      backgroundColor: Colors.green[800], // Çim rengi
      body: Stack(
        children: [
          // Yol
          Positioned(
            left: roadX,
            top: 0,
            bottom: 0,
            width: roadWidth,
            child: Container(
              color: Colors.grey[900],
              child: Row(
                children: [
                  // Şerit Çizgileri
                  _buildLaneDivider(),
                  const Spacer(),
                  _buildLaneDivider(),
                  const Spacer(),
                  _buildLaneDivider(),
                  const Spacer(),
                  _buildLaneDivider(),
                ],
              ),
            ),
          ),
          
          // Engeller
          ..._obstacles.map((obstacle) {
            return Positioned(
              left: roadX + (obstacle.lane * laneWidth) + (laneWidth - 40) / 2, // Ortala
              top: obstacle.y,
              child: Container(
                width: 40,
                height: obstacleHeight,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.directions_car, color: Colors.white),
              ),
            );
          }),

          // Oyuncu
          Positioned(
            left: roadX + (_playerLane * laneWidth) + (laneWidth - 40) / 2,
            bottom: 150 - playerHeight, // Alt boşluk
            child: Container(
              width: 40,
              height: playerHeight,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.local_taxi, color: Colors.black),
            ),
          ),

          // HUD (Bilgi Ekranı)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_moneyEarned TL',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                if (!_isPlaying && !_isGameOver)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'BAŞLAMAK İÇİN DOKUN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Başlatma Katmanı
          if (!_isPlaying && !_isGameOver)
            Positioned.fill(
              child: GestureDetector(
                onTap: _startGame,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Icon(Icons.play_circle_outline, size: 80, color: Colors.white),
                  ),
                ),
              ),
            ),

          // Kontroller
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sol Buton
                GestureDetector(
                  onTap: _moveLeft,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, size: 40),
                  ),
                ),
                // Sağ Buton
                GestureDetector(
                  onTap: _moveRight,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward, size: 40),
                  ),
                ),
              ],
            ),
          ),
          
          // Geri Butonu
          Positioned(
            top: 50,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_isPlaying) {
                  _gameLoop?.cancel();
                  // Oyundan çıkarken kazanılan parayı kaydetmek isteyebiliriz ama
                  // genelde "yanınca" kazanılır. Şimdilik çıkışta kaydetmeyelim.
                }
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaneDivider() {
    return Container(
      width: 2,
      height: double.infinity,
      color: Colors.white.withOpacity(0.3),
    );
  }
}

class Obstacle {
  int lane;
  double y;

  Obstacle({required this.lane, required this.y});
}
