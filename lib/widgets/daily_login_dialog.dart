import 'package:flutter/material.dart';
import '../services/daily_login_service.dart';
import '../services/ad_service.dart';

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
            const SnackBar(content: Text('Reklam yüklenemedi, normal ödül alınıyor.')),
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ödül alınırken bir hata oluştu.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Günlük Giriş Ödülü',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 20),
            
            // 7 Günlük Kartlar
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isCurrent = day == widget.currentStreak;
                  final isPast = day < widget.currentStreak;
                  final isBigReward = day == 7;
                  
                  return Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCurrent ? Colors.amber.shade100 : (isPast ? Colors.grey.shade200 : Colors.white),
                      border: Border.all(
                        color: isCurrent ? Colors.amber : Colors.grey.shade300,
                        width: isCurrent ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Gün $day',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.deepPurple : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.star,
                          color: isBigReward ? Colors.orange : Colors.amber,
                          size: isBigReward ? 24 : 18,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isBigReward ? '0.2' : '0.1',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.deepPurple : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Normal Al Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isClaiming ? null : () => _handleClaim(doubleReward: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Ödülü Al (${widget.currentStreak == 7 ? "0.2" : "0.1"} Altın)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Reklamla 2x Al Butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isClaiming ? null : () => _handleClaim(doubleReward: true),
                icon: const Icon(Icons.play_circle_filled, color: Colors.deepPurple),
                label: Text(
                  '2x Ödül Al (Reklam İzle)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
