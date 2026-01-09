import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/localization_service.dart';
import 'friends_tab.dart';
import 'requests_tab.dart';
import 'search_tab.dart';

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
