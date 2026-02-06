import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/localization_service.dart';
import 'friends_tab.dart';
import 'requests_tab.dart';
import 'search_tab.dart';
import '../../widgets/modern_alert_dialog.dart';

import 'dart:io';
import '../../services/asset_service.dart';
import '../../widgets/social_background.dart';

class SocialHubScreen extends StatefulWidget {
  const SocialHubScreen({super.key});

  @override
  State<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends State<SocialHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEULA();
    });
  }

  Future<void> _checkEULA() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('social_eula_accepted') ?? false;

    if (!accepted && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ModernAlertDialog(
          title: 'Safe Social Environment',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to the Social Hub! To ensure a safe and positive experience for everyone, please agree to the following rules:',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              _buildRuleItem('• Be respectful to others.'),
              _buildRuleItem('• Do not spam or harass other users.'),
              _buildRuleItem(
                '• Use the "Respect" feature to show appreciation.',
              ),
              const SizedBox(height: 12),
              Text(
                'Violation of these rules may result in restricted access to social features.',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          buttonText: 'I Agree',
          onPressed: () async {
            await prefs.setBool('social_eula_accepted', true);
            if (mounted) Navigator.pop(context);
          },
          secondaryButtonText: 'Cancel',
          onSecondaryPressed: () => Navigator.of(context)
            ..pop()
            ..pop(), // Pop dialog then screen
          icon: Icons.safety_check,
          iconColor: Colors.blueAccent,
        ),
      );
    }
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.deepPurple.shade900,
          elevation: 0,
          title: Text(
            'drawer.social.title'.tr(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'drawer.social.friends'.tr()),
              Tab(text: 'drawer.social.requests'.tr()),
              Tab(text: 'drawer.social.search'.tr()),
            ],
          ),
        ),
        body: SocialBackground(
          child: const TabBarView(
            children: [FriendsTab(), RequestsTab(), SearchTab()],
          ),
        ),
      ),
    );
  }
}
