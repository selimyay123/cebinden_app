import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';
import '../services/localization_service.dart';
import '../services/ad_service.dart';
import '../services/activity_service.dart';
import '../services/activity_service.dart';

enum ObstacleType { car, pedestrian }

class TaxiGameScreen extends StatefulWidget {
  const TaxiGameScreen({super.key});

  @override
  State<TaxiGameScreen> createState() => _TaxiGameScreenState();
}

class _TaxiGameScreenState extends State<TaxiGameScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final AdService _adService = AdService();
  
  // Oyun Ayarları
  static const int laneCount = 3;
  static const double laneWidth = 80.0;
  static const double playerHeight = 70.0;
  static const double obstacleHeight = 70.0;
  static const double coinSize = 40.0;
  static const int rewardPerCoin = 25;
  
  // Oyun Durumu
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _moneyEarned = 0;
  int _xpEarned = 0; // 🆕 XP Kazancı
  double _goldEarned = 0.0; // 🆕 Altın Kazancı
  int _coinsCollected = 0;
  int _playerLane = 1; // 0: Sol, 1: Orta, 2: Sağ
  double _gameSpeed = 400.0; // 🆕 Başlangıç hızı düşürüldü (500 -> 400)
  late Ticker _ticker;
  Duration? _lastElapsed;
  
  // Objeler
  final List<Obstacle> _obstacles = [];
  final List<Coin> _coins = [];
  
  // Yol Animasyonu
  double _distanceTraveled = 0;
  double _nextSpawnDistance = 200;
  double _roadOffset = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying || _isGameOver) return;

    final dt = (elapsed - (_lastElapsed ?? elapsed)).inMilliseconds / 1000.0;
    _lastElapsed = elapsed;

    if (dt > 0.1) return; // Çok büyük atlamaları (lag spike) yoksay

    setState(() {
      _updateGame(dt);
    });
  }

  void _startGame() {
    _adService.loadRewardedAd();

    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _moneyEarned = 0;
      _xpEarned = 0;
      _goldEarned = 0.0;
      _coinsCollected = 0;
      _playerLane = 1;
      _gameSpeed = 400.0; // 🆕 Yavaş başlangıç
      _obstacles.clear();
      _coins.clear();
      _distanceTraveled = 0;
      _nextSpawnDistance = 200;
      _roadOffset = 0;
      _lastElapsed = null;
    });

    _ticker.start();
  }

  void _updateGame(double dt) {
    // Hızlandırma (Her 1000px'de bir %5 hızlan)
    // 🆕 Daha dengeli hızlanma: Her 1000px'de bir %2 hızlan
    if (_distanceTraveled % 1000 < (_gameSpeed * dt)) {
       _gameSpeed *= 1.02; 
       if (_gameSpeed > 1000) _gameSpeed = 1000; // Max hız düşürüldü
    }
    
    final moveAmount = _gameSpeed * dt;
    _distanceTraveled += moveAmount;
    
    // Yol animasyonu
    _roadOffset = (_roadOffset + moveAmount) % 100;

    // Engel ve Coin Oluşturma
    if (_distanceTraveled >= _nextSpawnDistance) {
      _spawnObjects();
      _nextSpawnDistance = _distanceTraveled + 300 + Random().nextInt(200); // 🆕 Mesafe kısaltıldı
    }

    // Engelleri Hareket Ettir
    for (var i = _obstacles.length - 1; i >= 0; i--) {
      _obstacles[i].y += moveAmount;

      if (_obstacles[i].y > MediaQuery.of(context).size.height) {
        _obstacles.removeAt(i);
        _score++;
        
        // 🆕 XP Ödülü: Her 5 engel geçişinde 1 XP
        if (_score % 5 == 0) {
          _xpEarned++;
        }
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
      _coins[i].y += moveAmount;

      if (_coins[i].y > MediaQuery.of(context).size.height) {
        _coins.removeAt(i);
      } else {
        // Toplama Kontrolü
        final playerY = MediaQuery.of(context).size.height - 180;
        
        if (_coins[i].lane == _playerLane &&
            _coins[i].y + coinSize > playerY &&
            _coins[i].y < playerY + playerHeight) {
          
          // 🆕 Altın Coin Kontrolü
          if (_coins[i].isGold) {
            _goldEarned += 0.1;
          } else {
            _moneyEarned += rewardPerCoin;
          }
          
          _coinsCollected++;
          _coins.removeAt(i);
        }
      }
    }
  }

  void _spawnObjects() {
    final random = Random();
    int obstacleLane = random.nextInt(laneCount);
    
    // 🆕 Engel Tipi Seçimi (%20 yaya, %80 araba)
    ObstacleType type = random.nextDouble() < 0.2 ? ObstacleType.pedestrian : ObstacleType.car;
    
    _obstacles.add(Obstacle(lane: obstacleLane, y: -100, type: type));
    
    // %40 şansla coin ekle
    if (random.nextDouble() < 0.4) {
      int coinLane;
      do {
        coinLane = random.nextInt(laneCount);
      } while (coinLane == obstacleLane);
      
      // 🆕 %1 şansla Altın Coin (Daha nadir)
      bool isGold = random.nextDouble() < 0.01;
      
      _coins.add(Coin(lane: coinLane, y: -100, isGold: isGold));
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
    _ticker.stop();
    setState(() {
      _isGameOver = true;
      _isPlaying = false;
    });

    // Ödülleri ver
    final userMap = await _db.getCurrentUser();
    if (userMap != null) {
      final user = User.fromJson(userMap);
      
      await _db.updateUser(user.id, {
        'balance': user.balance + _moneyEarned,
        'xp': user.xp + _xpEarned, // 🆕 XP ekle
        'gold': user.gold + _goldEarned, // 🆕 Altın ekle
      });

      // Aktivite kaydı
      if (_moneyEarned > 0) {
        await ActivityService().logTaxiEarnings(user.id, _moneyEarned.toDouble());
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
          backgroundColor: Colors.white.withOpacity(0.9),
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
                // 🆕 XP ve Altın Göstergesi
                if (_xpEarned > 0 || _goldEarned > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_xpEarned > 0) ...[
                        const Icon(Icons.star, color: Colors.blue, size: 16),
                        const SizedBox(width: 4),
                        Text('taxiGame.earnedXP'.trParams({'amount': '$_xpEarned'}), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                      ],
                      if (_goldEarned > 0) ...[
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('taxiGame.earnedGold'.trParams({'amount': _goldEarned.toStringAsFixed(1)}), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ],
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
                              
                              final finalReward = _moneyEarned;
                              
                              await _db.updateUser(user.id, {
                                'balance': user.balance + finalReward, // Ekstra kazanç (zaten ilk kazanç eklendi)
                              });

                              // Aktivite kaydı (Ekstra kazanç)
                              await ActivityService().logTaxiEarnings(user.id, finalReward.toDouble());
                            }
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  behavior: SnackBarBehavior.floating,
                                  content: Text('taxiGame.rewardDoubled'.tr()),
                                  backgroundColor: Colors.green.withOpacity(0.8),
                                ),
                              );
                              Navigator.pop(context);
                              Navigator.pop(context);
                            }
                          },
                          onAdNotReady: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                elevation: 8,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                behavior: SnackBarBehavior.floating,
                                content: Text('taxiGame.adNotReady'.tr()),
                                backgroundColor: Colors.grey.withOpacity(0.8),
                              ),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final roadWidth = laneCount * laneWidth;
    final roadX = (screenWidth - roadWidth) / 2;
    final playerY = MediaQuery.of(context).size.height - 180;

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
            // Tüm oyun çizimi (CustomPainter)
            Positioned.fill(
              child: CustomPaint(
                painter: GamePainter(
                  roadOffset: _roadOffset,
                  roadX: roadX,
                  roadWidth: roadWidth,
                  laneWidth: laneWidth,
                  playerLane: _playerLane,
                  playerY: playerY,
                  playerHeight: playerHeight,
                  obstacles: _obstacles,
                  coins: _coins,
                  coinSize: coinSize,
                  obstacleHeight: obstacleHeight,
                ),
              ),
            ),

            // HUD (Skor ve Para)
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
  ObstacleType type; // 🆕 Engel Tipi

  Obstacle({required this.lane, required this.y, this.type = ObstacleType.car});
}

class Coin {
  int lane;
  double y;
  bool isGold; // 🆕 Altın Coin mi?

  Coin({required this.lane, required this.y, this.isGold = false});
}

class GamePainter extends CustomPainter {
  final double roadOffset;
  final double roadX;
  final double roadWidth;
  final double laneWidth;
  final int playerLane;
  final double playerY;
  final double playerHeight;
  final List<Obstacle> obstacles;
  final List<Coin> coins;
  final double coinSize;
  final double obstacleHeight;

  GamePainter({
    required this.roadOffset,
    required this.roadX,
    required this.roadWidth,
    required this.laneWidth,
    required this.playerLane,
    required this.playerY,
    required this.playerHeight,
    required this.obstacles,
    required this.coins,
    required this.coinSize,
    required this.obstacleHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Çim (Arkaplan)
    final grassPaint = Paint()..color = Colors.green[800]!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), grassPaint);

    // 2. Yol
    final roadPaint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.fill;
    
    // Yol kenar çizgileri
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final roadRect = Rect.fromLTWH(roadX, 0, roadWidth, size.height);
    
    // Gölge
    final shadowPath = Path()..addRect(roadRect);
    canvas.drawShadow(shadowPath, Colors.black, 10, true);
    
    canvas.drawRect(roadRect, roadPaint);
    canvas.drawRect(roadRect, borderPaint);

    // 3. Şerit Çizgileri
    final lanePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (int i = 1; i < 3; i++) { // 3 şerit için 2 çizgi
      double laneX = roadX + (i * laneWidth);
      for (int j = -1; j < 15; j++) {
        double lineY = (j * 100) + roadOffset - 50; // 100px aralık
        canvas.drawRect(
          Rect.fromLTWH(laneX - 2, lineY, 4, 60),
          lanePaint,
        );
      }
    }

    // 4. Coinler
    final coinPaint = Paint()..color = Colors.green[700]!;
    final goldCoinPaint = Paint()..color = Colors.amber[600]!; // 🆕 Altın Rengi
    final coinBorderPaint = Paint()
      ..color = Colors.green[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (var coin in coins) {
      double coinX = roadX + (coin.lane * laneWidth) + (laneWidth - coinSize) / 2;
      final coinRect = Rect.fromLTWH(coinX, coin.y, coinSize, coinSize);
      
      // Gölge
      canvas.drawRect(
        coinRect.shift(const Offset(0, 2)), 
        Paint()..color = Colors.black.withOpacity(0.3)
      );

      canvas.drawRect(coinRect, coin.isGold ? goldCoinPaint : coinPaint);
      canvas.drawRect(coinRect, coinBorderPaint);
      
      // İçine dolar işareti ($) veya G
      _drawText(canvas, coin.isGold ? 'G' : '\$', coinX + coinSize/2, coin.y + coinSize/2, 
        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold);
    }

    // 5. Engeller (Arabalar ve Yayalar)
    final carPaint = Paint()..color = Colors.red[700]!;
    final pedestrianPaint = Paint()..color = Colors.blue[700]!; // 🆕 Yaya Rengi
    
    for (var obstacle in obstacles) {
      double obsX = roadX + (obstacle.lane * laneWidth) + (laneWidth - 50) / 2;
      
      if (obstacle.type == ObstacleType.car) {
        // ARABA ÇİZİMİ
        final obsRect = Rect.fromLTWH(obsX, obstacle.y, 50, obstacleHeight);
        
        // Gölge
        canvas.drawRRect(
          RRect.fromRectAndRadius(obsRect.shift(const Offset(0, 4)), const Radius.circular(12)),
          Paint()..color = Colors.black.withOpacity(0.4)
        );

        // Araba Gövdesi
        canvas.drawRRect(
          RRect.fromRectAndRadius(obsRect, const Radius.circular(12)),
          carPaint,
        );
        
        // Stop lambaları
        final lightPaint = Paint()..color = Colors.redAccent;
        canvas.drawRect(Rect.fromLTWH(obsX + 8, obstacle.y + obstacleHeight - 11, 6, 3), lightPaint);
        canvas.drawRect(Rect.fromLTWH(obsX + 50 - 14, obstacle.y + obstacleHeight - 11, 6, 3), lightPaint);
        
        // Cam
        final windowPaint = Paint()..color = Colors.black.withOpacity(0.3);
        canvas.drawRect(Rect.fromLTWH(obsX + 5, obstacle.y + 15, 40, 20), windowPaint);
        
      } else {
        // 🆕 YAYA ÇİZİMİ (Basit)
        double pedWidth = 30;
        double pedHeight = 30;
        double pedX = obsX + (50 - pedWidth) / 2;
        double pedY = obstacle.y + (obstacleHeight - pedHeight) / 2;
        
        // Kafa
        canvas.drawCircle(Offset(pedX + pedWidth/2, pedY), 8, pedestrianPaint);
        
        // Gövde
        canvas.drawRect(Rect.fromLTWH(pedX, pedY + 8, pedWidth, 20), pedestrianPaint);
        
        // Kollar (Basit çizgi)
        // canvas.drawLine(...)
      }
    }

    // 6. Oyuncu (Taksi)
    double playerX = roadX + (playerLane * laneWidth) + (laneWidth - 50) / 2;
    
    final playerRect = Rect.fromLTWH(playerX, playerY, 50, playerHeight);
    
    // Gölge
    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect.shift(const Offset(0, 4)), const Radius.circular(12)),
      Paint()..color = Colors.black.withOpacity(0.4)
    );

    // Taksi Gövdesi
    final taxiPaint = Paint()..color = Colors.amber;
    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect, const Radius.circular(12)),
      taxiPaint,
    );
    
    // Taksi detayları
    final taxiBorderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect, const Radius.circular(12)),
      taxiBorderPaint,
    );

    // Tavan Işığı
    canvas.drawRect(
      Rect.fromLTWH(playerX + 15, playerY + 10, 20, 6),
      Paint()..color = Colors.black
    );
    
    // Cam
    canvas.drawRect(
      Rect.fromLTWH(playerX + 5, playerY + 20, 40, 15),
      Paint()..color = Colors.black.withOpacity(0.2)
    );
    
    // Damalı şerit (Basit)
    final checkPaint = Paint()..color = Colors.black;
    for(int k=0; k<5; k++) {
       if(k%2==0) {
         canvas.drawRect(Rect.fromLTWH(playerX + (k*10), playerY + 40, 10, 5), checkPaint);
       }
    }
  }

  void _drawText(Canvas canvas, String text, double x, double y, 
      {Color color = Colors.white, double fontSize = 14, FontWeight fontWeight = FontWeight.normal}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return true; // Her frame'de yeniden çiz
  }
}
