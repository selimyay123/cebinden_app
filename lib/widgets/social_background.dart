import 'dart:io';
import 'package:flutter/material.dart';
import '../services/asset_service.dart';

class SocialBackground extends StatefulWidget {
  final Widget child;
  
  const SocialBackground({
    super.key, 
    required this.child,
  });

  @override
  State<SocialBackground> createState() => _SocialBackgroundState();
}

class _SocialBackgroundState extends State<SocialBackground> {
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Fallback color
        image: _bgFile != null
            ? DecorationImage(
                image: FileImage(_bgFile!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Stack(
        children: [
          // Karartma Katmanı (Okunabilirlik için)
          if (_bgFile != null)
            Container(
              color: Colors.black.withOpacity(0.7),
            ),
            
          // İçerik
          widget.child,
        ],
      ),
    );
  }
}
