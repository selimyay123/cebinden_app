import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';

class ProfileInfoScreen extends StatelessWidget {
  final User user;

  const ProfileInfoScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Profil Bilgileri'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profil Avatarı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.deepPurple.withOpacity(0.1),
                    child: Icon(
                      user.gender == 'Erkek' ? Icons.person : Icons.person_outline,
                      size: 50,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kullanıcı ID: ${user.id.substring(0, 8)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Kişisel Bilgiler
            _buildInfoCard(
              title: 'Kişisel Bilgiler',
              icon: Icons.person_outline,
              children: [
                _buildInfoRow('Kullanıcı Adı', user.username),
                _buildInfoRow('Cinsiyet', user.gender),
                _buildInfoRow('Doğum Tarihi', _formatDate(user.birthDate)),
                _buildInfoRow('Yaş', '${user.age} yaşında'),
              ],
            ),

            const SizedBox(height: 12),

            // Hesap Bilgileri
            _buildInfoCard(
              title: 'Hesap Bilgileri',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                _buildInfoRow('Bakiye', '${_formatCurrency(user.balance)} ${user.currency}'),
                _buildInfoRow(
                  'Kar/Zarar',
                  '${user.profitLossPercentage >= 0 ? '+' : ''}${user.profitLossPercentage.toStringAsFixed(2)}%',
                  valueColor: user.profitLossPercentage >= 0 ? Colors.green : Colors.red,
                ),
                _buildInfoRow('Para Birimi', user.currency),
              ],
            ),

            const SizedBox(height: 12),

            // Kayıt Bilgileri
            _buildInfoCard(
              title: 'Kayıt Bilgileri',
              icon: Icons.calendar_today_outlined,
              children: [
                _buildInfoRow('Kayıt Tarihi', _formatDate(user.registeredAt)),
                _buildInfoRow('Üyelik Süresi', _getMembershipDuration()),
              ],
            ),

            const SizedBox(height: 20),

            // Bilgilendirme
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Profil düzenleme özelliği yakında eklenecek!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
  }

  String _getMembershipDuration() {
    final duration = DateTime.now().difference(user.registeredAt);
    if (duration.inDays < 30) {
      return '${duration.inDays} gün';
    } else if (duration.inDays < 365) {
      return '${(duration.inDays / 30).floor()} ay';
    } else {
      return '${(duration.inDays / 365).floor()} yıl';
    }
  }
}

