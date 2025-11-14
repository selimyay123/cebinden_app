import 'package:flutter/material.dart';
import '../services/localization_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('about.title'.tr()),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Logo ve Başlık
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/app_logo/cebinden_no_bg.png',
                    height: 180,
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cebinden',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Versiyon 1.0.0',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Açıklama
            _buildInfoCard(
              icon: Icons.info_outline,
              title: 'about.aboutApp'.tr(),
              content:
                  'Cebinden, eğlenceli ve interaktif bir araç alım-satım simülasyon oyunudur. '
                  'Sanal para ile araç alıp satabilir, kar elde edebilir ve garajınızı büyütebilirsiniz!\n\n'
                  'Bu oyunda gerçek para kullanılmaz, tüm işlemler tamamen simülasyondur. '
                  'İlan açıklamaları komik ve eğlence amaçlıdır.',
            ),

            const SizedBox(height: 12),

            // Özellikler
            _buildInfoCard(
              icon: Icons.star_outline,
              title: 'about.features'.tr(),
              content:
                  '✓ Çeşitli marka ve modellerde araçlar\n'
                  '✓ Detaylı filtreleme sistemi\n'
                  '✓ Komik ve eğlenceli ilan açıklamaları\n'
                  '✓ Kar/zarar takibi\n'
                  '✓ Kişiselleştirilebilir ayarlar\n'
                  '✓ Karanlık mod desteği (yakında)\n'
                  '✓ Çoklu para birimi desteği',
            ),

            const SizedBox(height: 12),

            // İletişim
            _buildInfoCard(
              icon: Icons.contact_mail_outlined,
              title: 'about.contactTitle'.tr(),
              content:
                  'Geri bildirim, öneri veya sorularınız için:\n\n'
                  '📧 E-posta: info@cebinden.com\n'
                  '🌐 Web: www.cebinden.com\n'
                  '📱 Instagram: @cebindenapp',
            ),

            const SizedBox(height: 12),

            // Geliştirici
            _buildInfoCard(
              icon: Icons.code,
              title: 'about.developerTitle'.tr(),
              content:
                  'Bu uygulama Flutter ile geliştirilmiştir.\n\n'
                  '© 2024 Cebinden\n'
                  'Tüm hakları saklıdır.',
            ),

            const SizedBox(height: 20),

            // Uyarı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bu bir oyun/simülasyon uygulamasıdır. Gerçek araç alım-satımı yapmaz. '
                      'Tüm işlemler sanal ve eğlence amaçlıdır.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sosyal Medya Butonları (Placeholder)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(Icons.language, 'Web'),
                const SizedBox(width: 12),
                _buildSocialButton(Icons.mail, 'E-posta'),
                const SizedBox(width: 12),
                _buildSocialButton(Icons.camera_alt, 'Instagram'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepPurple, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

