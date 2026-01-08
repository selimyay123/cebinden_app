import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/localization_service.dart';
import 'friends_tab.dart';
import 'requests_tab.dart';
import 'search_tab.dart';

import 'dart:io';
import '../../services/asset_service.dart';

class SocialHubScreen extends StatefulWidget {
  const SocialHubScreen({super.key});

  @override
  State<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends State<SocialHubScreen> {
  File? _bgFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBackground();
  }

  Future<void> _checkBackground() async {
    const assetPath = 'assets/images/social_bg.jpeg';
    final file = AssetService().getLocalFile(assetPath);
    
    if (file.existsSync()) {
      if (mounted) {
        setState(() {
          _bgFile = file;
          _isLoading = false;
        });
      }
    } else {
      // Dosya yok, indirmeyi dene
      final success = await AssetService().downloadAsset(assetPath);
      if (mounted) {
        setState(() {
          if (success) {
            _bgFile = AssetService().getLocalFile(assetPath);
          }
          _isLoading = false;
        });
      }
    }
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
        body: Container(
          decoration: BoxDecoration(
            image: _bgFile != null
                ? DecorationImage(
                    image: FileImage(_bgFile!),
                    fit: BoxFit.cover,
                  )
                : const DecorationImage(
                    image: AssetImage('assets/images/social_bg.jpeg'), // Fallback
                    fit: BoxFit.cover,
                  ),
            color: _bgFile == null ? const Color(0xFF121212) : null,
          ),
          child: const TabBarView(
            children: [
              FriendsTab(),
              RequestsTab(),
              SearchTab(),
            ],
          ),
        ),
      ),
    );
  }
}
