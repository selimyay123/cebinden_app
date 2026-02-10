// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/localization_service.dart';
import 'friends_tab.dart';
import 'requests_tab.dart';
import 'search_tab.dart';
import '../../widgets/modern_alert_dialog.dart';

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
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ModernAlertDialog(
          title: 'drawer.social.eula.title'.tr(),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'drawer.social.eula.description'.tr(),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _buildRuleItem('drawer.social.eula.rule1'.tr()),
              _buildRuleItem('drawer.social.eula.rule2'.tr()),
              _buildRuleItem('drawer.social.eula.rule3'.tr()),
              const SizedBox(height: 12),
              Text(
                'drawer.social.eula.footer'.tr(),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          buttonText: 'drawer.social.eula.button'.tr(),
          onPressed: () {
            Navigator.of(dialogContext).pop(true); // Return true
          },
          secondaryButtonText: 'common.cancel'.tr(),
          onSecondaryPressed: () {
            Navigator.of(dialogContext).pop(false); // Return false
          },
          icon: Icons.safety_check,
          iconColor: Colors.blueAccent,
        ),
      );

      // Handle result after dialog is closed using the screen's context
      if (result == true) {
        await prefs.setBool('social_eula_accepted', true);
      } else {
        // User cancelled or dismissed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('drawer.social.eula.declinedMessage'.tr()),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop(); // Go back to Home
        }
      }
    }
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
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
