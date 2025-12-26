import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/localization_service.dart'; // Custom localization service
import '../services/game_time_service.dart';
import '../screens/settings_screen.dart';

class GameTimeCountdown extends StatefulWidget {
  const GameTimeCountdown({Key? key}) : super(key: key);

  @override
  State<GameTimeCountdown> createState() => _GameTimeCountdownState();
}

class _GameTimeCountdownState extends State<GameTimeCountdown> {
  final GameTimeService _gameTime = GameTimeService();
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  int _currentHour = 0;
  int _totalDurationMinutes = 1;

  @override
  void initState() {
    super.initState();
    _totalDurationMinutes = _gameTime.getGameDayDuration();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _remainingTime = _gameTime.getTimeUntilNextDay();
        _currentHour = _gameTime.getCurrentHour();
        _totalDurationMinutes = _gameTime.getGameDayDuration();
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // Gündüz/Gece kontrolü (06:00 - 18:00 arası gündüz)
    final isDay = _currentHour >= 6 && _currentHour < 18;
    
    // İlerleme oranı (0.0 - 1.0)
    final totalSeconds = _totalDurationMinutes * 60;
    final remainingSeconds = _remainingTime.inSeconds;
    final progress = 1.0 - (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    // Renkler ve Gradientler
    final List<Color> gradientColors = isDay
        ? [const Color(0xFF4FC3F7), const Color(0xFFFFB74D)] // Gündüz: Mavi -> Turuncu
        : [const Color(0xFF311B92), const Color(0xFF1A237E)]; // Gece: Koyu Mor -> Lacivert

    final Color textColor = Colors.white;
    final Color progressColor = isDay ? Colors.orangeAccent : Colors.purpleAccent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Arkaplan desenleri (opsiyonel, hafif opaklıkta)
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.1,
              child: Lottie.asset(
                'assets/animations/day  night.json',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Animasyon
                Lottie.asset(
                  'assets/animations/day  night.json',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
                
                const SizedBox(width: 16),
                
                // Metinler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'home.nextDayIn'.tr(),
                        style: TextStyle(
                          color: textColor.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(_remainingTime),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Ayarlar Butonu (Küçültülmüş)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                    tooltip: 'home.changeTimeZone'.tr(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
