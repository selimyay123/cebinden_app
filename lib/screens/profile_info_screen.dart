import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/user_model.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';

class ProfileInfoScreen extends StatelessWidget {
  final User user;

  const ProfileInfoScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('profile.title'.tr()),
        actions: [],
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
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(user.profileImageUrl),
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Kişisel Bilgiler
            _buildInfoCard(
              title: 'profile.personalInfo'.tr(),
              icon: Icons.person_outline,
              children: [_buildInfoRow('profile.username'.tr(), user.username)],
            ),

            const SizedBox(height: 12),

            // Kayıt Bilgileri
            _buildInfoCard(
              title: 'profile.registrationInfo'.tr(),
              icon: Icons.calendar_today_outlined,
              children: [
                _buildInfoRow(
                  'profile.registrationDate'.tr(),
                  _formatDate(user.registeredAt),
                ),
                _buildInfoRow(
                  'profile.membershipDuration'.tr(),
                  _getMembershipDuration(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.person, size: 50, color: Colors.deepPurple);
    }

    if (imageUrl.endsWith('.json')) {
      return Lottie.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, size: 50, color: Colors.deepPurple);
        },
      );
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, size: 50, color: Colors.deepPurple);
        },
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.person, size: 50, color: Colors.deepPurple);
      },
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
            color: Colors.black.withValues(alpha: 0.05),
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
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
  }

  String _getMembershipDuration() {
    final duration = DateTime.now().difference(user.registeredAt);
    if (duration.inDays < 30) {
      return '${duration.inDays} ${'misc.day'.tr()}';
    } else if (duration.inDays < 365) {
      return '${(duration.inDays / 30).floor()} ${'misc.month'.tr()}';
    } else {
      return '${(duration.inDays / 365).floor()} ${'misc.year'.tr()}';
    }
  }
}
