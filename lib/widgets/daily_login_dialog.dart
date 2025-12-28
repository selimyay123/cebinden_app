import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/daily_login_service.dart';
import '../services/ad_service.dart';
import '../services/localization_service.dart';

class DailyLoginDialog extends StatefulWidget {
  final String userId;
  final int currentStreak;
  final VoidCallback onClaim;

  const DailyLoginDialog({
    super.key,
    required this.userId,
    required this.currentStreak,
    required this.onClaim,
  });

  @override
  State<DailyLoginDialog> createState() => _DailyLoginDialogState();
}

class _DailyLoginDialogState extends State<DailyLoginDialog> {
  final DailyLoginService _loginService = DailyLoginService();
  final AdService _adService = AdService();
  bool _isClaiming = false;

  Future<void> _handleClaim({bool doubleReward = false}) async {
    setState(() => _isClaiming = true);

    if (doubleReward) {
      // Reklam göster
      final adResult = await _adService.showRewardedAd();
      if (!adResult) {
        // Reklam izlenmedi veya yüklenemedi
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.grey[800]!.withOpacity(0.8),
              content: const Text('Reklam yüklenemedi, normal ödül alınıyor.'),
            ),
          );
        }
        // Normal ödül devam etsin mi? Kullanıcıya sorulabilir ama şimdilik normal ödülü verelim
        // doubleReward = false; // İsteğe bağlı
      }
    }

    final success = await _loginService.claimReward(widget.userId, isDouble: doubleReward);

    if (mounted) {
      setState(() => _isClaiming = false);
      if (success) {
        Navigator.pop(context); // Dialogu kapat
        widget.onClaim(); // Callback'i çağır (örn: konfeti patlat)
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4CAF50),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'xp.source.dailyRewardClaimed'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.withOpacity(0.8),
            content: const Text('Ödül alınırken bir hata oluştu.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Main Card Content
          Container(
            margin: const EdgeInsets.only(top: 0, bottom: 80), // Space for buttons bottom
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gold Header Background
                Container(
                  height: 60,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE0AA3E), Color(0xFFF7D57E)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                ),
                
                // Content Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
                  child: Column(
                    children: [
                      // Title Pill
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        transform: Matrix4.translationValues(0, -45, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4982F),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'GÜNLÜK ÖDÜL',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ),

                      // Days 1-6 Grid (3 columns)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          final day = index + 1;
                          final isCurrent = day == widget.currentStreak;
                          final isPast = day < widget.currentStreak;
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: isCurrent ? const Color(0xFF4CAF50) : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isCurrent ? [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ] : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'GÜN $day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(isCurrent ? 0.2 : 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Lottie.asset(
                                    'assets/animations/gold.json',
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '0.1',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? Colors.white : Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Day 7 (Large Card)
                      Container(
                        width: double.infinity,
                        height: 100,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                          // Removed missing asset
                        ),
                        child: Row(
                          children: [
                            // Character/Icon Placeholder
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Lottie.asset(
                                'assets/animations/gold.json',
                                width: 40,
                                height: 40,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'BÜYÜK ÖDÜL',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      '0.2 Altın',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),



          // Close Button (Top Right)
          Positioned(
            top: 40,
            right: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),

          // Bottom Buttons (Floating below card)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ElevatedButton(
              onPressed: _isClaiming ? null : () => _handleClaim(doubleReward: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: Text(
                'AL',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
