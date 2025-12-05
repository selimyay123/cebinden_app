import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';
import '../services/localization_service.dart';
import '../services/ad_service.dart';

class TaxiGameScreen extends StatefulWidget {
  const TaxiGameScreen({super.key});

  @override
  State<TaxiGameScreen> createState() => _TaxiGameScreenState();
}

class _TaxiGameScreenState extends State<TaxiGameScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final AdService _adService = AdService();
  
  // Oyun Ayarları
  static const int laneCount = 3;
  static const double laneWidth = 80.0;
  static const double playerHeight = 70.0;
  static const double obstacleHeight = 70.0;
  static const double coinSize = 40.0;
  static const int baseRewardPerCar = 0; // Artık araç geçince para yok
  static const int rewardPerCoin = 50; // Para destesi değeri
  
  // Oyun Durumu
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0; // Geçilen araç sayısı
  int _moneyEarned = 0;
  int _coinsCollected = 0;
  int _playerLane = 1; // 0: Sol, 1: Orta, 2: Sağ
  double _gameSpeed = 6.0;
  Timer? _gameLoop;
  
  // Objeler
  final List<Obstacle> _obstacles = [];
  final List<Coin> _coins = [];
  
  // Yol Animasyonu
  double _distanceTraveled = 0;
  double _nextSpawnDistance = 200;
  double _roadOffset = 0;

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }

  void _startGame() {
    _adService.loadRewardedAd();

    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _moneyEarned = 0;
      _coinsCollected = 0;
      _playerLane = 1;
      _gameSpeed = 6.0;
      _obstacles.clear();
      _coins.clear();
      _distanceTraveled = 0;
      _nextSpawnDistance = 200;
      _roadOffset = 0;
    });

    _gameLoop = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      _updateGame();
    });
  }

  void _updateGame() {
    if (!_isPlaying || _isGameOver) return;

    setState(() {
      // Hızlandırma
      if (_distanceTraveled % 1000 < _gameSpeed) {
        _gameSpeed += 0.05;
      }
      
      _distanceTraveled += _gameSpeed;
      
      // Yol animasyonu
      _roadOffset = (_roadOffset + _gameSpeed) % 100;

      // Engel ve Coin Oluşturma
      if (_distanceTraveled >= _nextSpawnDistance) {
        _spawnObjects();
        _nextSpawnDistance = _distanceTraveled + 350 + Random().nextInt(250);
      }

      // Engelleri Hareket Ettir
      for (var i = _obstacles.length - 1; i >= 0; i--) {
        _obstacles[i].y += _gameSpeed;

        if (_obstacles[i].y > MediaQuery.of(context).size.height) {
          _obstacles.removeAt(i);
          _score++;
          // _moneyEarned += baseRewardPerCar; // Para kazanma kaldırıldı
        } else {
          // Çarpışma Kontrolü
          final playerY = MediaQuery.of(context).size.height - 180;
          
          if (_obstacles[i].lane == _playerLane &&
              _obstacles[i].y + obstacleHeight > playerY + 10 &&
              _obstacles[i].y < playerY + playerHeight - 10) {
            _gameOver();
          }
        }
      }

      // Coinleri Hareket Ettir
      for (var i = _coins.length - 1; i >= 0; i--) {
        _coins[i].y += _gameSpeed;

        if (_coins[i].y > MediaQuery.of(context).size.height) {
          _coins.removeAt(i);
        } else {
          // Toplama Kontrolü
          final playerY = MediaQuery.of(context).size.height - 180;
          
          if (_coins[i].lane == _playerLane &&
              _coins[i].y + coinSize > playerY &&
              _coins[i].y < playerY + playerHeight) {
            _coins.removeAt(i);
            _coinsCollected++;
            _moneyEarned += rewardPerCoin;
          }
        }
      }
    });
  }

  void _spawnObjects() {
    final random = Random();
    int obstacleLane = random.nextInt(laneCount);
    
    // Engel ekle
    _obstacles.add(Obstacle(lane: obstacleLane, y: -100));
    
    // %40 şansla coin ekle
    if (random.nextDouble() < 0.4) {
      int coinLane;
      do {
        coinLane = random.nextInt(laneCount);
      } while (coinLane == obstacleLane);
      
      _coins.add(Coin(lane: coinLane, y: -100));
    }
  }

  void _moveLeft() {
    if (!_isPlaying) return;
    if (_playerLane > 0) {
      setState(() => _playerLane--);
    }
  }

  void _moveRight() {
    if (!_isPlaying) return;
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
        builder: (context) => _buildGameOverDialog(),
      );
    }
  }

  Widget _buildGameOverDialog() {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.flag, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'taxiGame.gameOver'.tr(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'taxiGame.totalEarnings'.tr(),
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: Text(
                        'taxiGame.vehicleCount'.trParams({'count': '$_score'}),
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'taxiGame.stackCount'.trParams({'count': '$_coinsCollected'}),
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_moneyEarned > 0) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _adService.showRewardedAd(
                          onRewarded: (reward) async {
                            final userMap = await _db.getCurrentUser();
                            if (userMap != null) {
                              final user = User.fromJson(userMap);
                              await _db.updateUser(user.id, {
                                'balance': user.balance + _moneyEarned,
                              });
                            }
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('taxiGame.rewardDoubled'.tr()),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.pop(context);
                              Navigator.pop(context);
                            }
                          },
                          onAdNotReady: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('taxiGame.adNotReady'.tr())),
                            );
                            _adService.loadRewardedAd();
                          },
                        );
                      },
                      icon: const Icon(Icons.play_circle_filled),
                      label: Text('taxiGame.doubleEarnings'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'taxiGame.exit'.tr(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _startGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'taxiGame.playAgain'.tr(),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[700], size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final roadWidth = laneCount * laneWidth;
    final roadX = (screenWidth - roadWidth) / 2;

    return Scaffold(
      backgroundColor: Colors.green[800],
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            _moveRight();
          } else if (details.primaryVelocity! < 0) {
            _moveLeft();
          }
        },
        child: Stack(
          children: [
            // Çim Desenleri
            Positioned.fill(
              child: CustomPaint(
                painter: GrassPainter(_roadOffset),
              ),
            ),

            // Yol
            Positioned(
              left: roadX,
              top: 0,
              bottom: 0,
              width: roadWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.symmetric(
                    vertical: BorderSide(color: Colors.white, width: 4),
                  ),
                ),
                child: Stack(
                  children: [
                    // Hareketli Şerit Çizgileri
                    ...List.generate(laneCount - 1, (index) {
                      return Positioned(
                        left: (index + 1) * laneWidth - 2,
                        top: -100 + _roadOffset,
                        // bottom constraint removed
                        child: Column(
                          children: List.generate(15, (i) {
                            return Container(
                              width: 4,
                              height: 60,
                              margin: const EdgeInsets.only(bottom: 40),
                              color: Colors.white.withOpacity(0.5),
                            );
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            
            // Coinler (Para Desteleri)
            ..._coins.map((coin) {
              return Positioned(
                left: roadX + (coin.lane * laneWidth) + (laneWidth - coinSize) / 2,
                top: coin.y,
                child: Container(
                  width: coinSize,
                  height: coinSize,
                  decoration: BoxDecoration(
                    color: Colors.green[700], // Para yeşili
                    borderRadius: BorderRadius.circular(4), // Dikdörtgenimsi
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.green[300]!, width: 1),
                  ),
                  child: const Icon(Icons.local_atm, color: Colors.white, size: 24),
                ),
              );
            }),

            // Engeller (Arabalar)
            ..._obstacles.map((obstacle) {
              return Positioned(
                left: roadX + (obstacle.lane * laneWidth) + (laneWidth - 50) / 2,
                top: obstacle.y,
                child: Container(
                  width: 50,
                  height: obstacleHeight,
                  decoration: BoxDecoration(
                    color: Colors.red[700],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(Icons.directions_car_filled, color: Colors.white, size: 40),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(width: 6, height: 3, color: Colors.redAccent),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(width: 6, height: 3, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Oyuncu (Taksi)
            Positioned(
              left: roadX + (_playerLane * laneWidth) + (laneWidth - 50) / 2,
              bottom: 180 - playerHeight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 50,
                height: playerHeight,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.local_taxi, color: Colors.black, size: 40),
                    ),
                    Positioned(
                      top: 10,
                      left: 15,
                      right: 15,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // HUD
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Para Göstergesi
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_atm, color: Colors.green, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '$_moneyEarned',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Skor (Araç)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.amber, width: 2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.speed, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '$_score',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Başlatma Ekranı
            if (!_isPlaying && !_isGameOver)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_taxi, size: 80, color: Colors.amber),
                      const SizedBox(height: 20),
                      Text(
                        'taxiGame.title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'taxiGame.collectMoney'.tr(),
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'taxiGame.swipeToMove'.tr(),
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: _startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'taxiGame.start'.tr(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Geri Butonu
            if (!_isPlaying)
              Positioned(
                top: 50,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Obstacle {
  int lane;
  double y;

  Obstacle({required this.lane, required this.y});
}

class Coin {
  int lane;
  double y;

  Coin({required this.lane, required this.y});
}

class GrassPainter extends CustomPainter {
  final double offset;
  GrassPainter(this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.green[900]!;
    // Basit desenler çizilebilir
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
