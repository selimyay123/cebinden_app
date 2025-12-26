import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/localization_service.dart';
import 'friends_tab.dart';
import 'requests_tab.dart';
import 'search_tab.dart';

class SocialHubScreen extends StatelessWidget {
  const SocialHubScreen({super.key});

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
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/social_bg.jpeg'),
              fit: BoxFit.cover,
            ),
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
