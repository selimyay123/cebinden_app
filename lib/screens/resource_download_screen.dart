import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/asset_service.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';


class ResourceDownloadScreen extends StatefulWidget {
  const ResourceDownloadScreen({super.key});

  @override
  State<ResourceDownloadScreen> createState() => _ResourceDownloadScreenState();
}

class _ResourceDownloadScreenState extends State<ResourceDownloadScreen> {
  final AssetService _assetService = AssetService();
  String _statusMessage = '';
  double _progress = 0.0;
  String _currentFile = '';

  @override
  void initState() {
    super.initState();
    // Defer initialization to ensure context is available for localization if needed immediately,
    // though we are awaiting in _startDownload so it might be fine.
    // But to be safe and clean, let's just start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDownload();
    });
  }

  Future<void> _startDownload() async {
    setState(() {
      _statusMessage = LocalizationService().translate('resourceDownload.checking');
    });
    
    await _assetService.init();

    if (!mounted) return;
    setState(() {
      _statusMessage = LocalizationService().translate('resourceDownload.downloading');
    });

    // Sync critical folders
    // We sync 'assets/images' and 'assets/car_images'
    // You can add more folders here
    
    int totalFiles = 0; // We don't know total files easily without listing first, 
                        // so we just show "Downloading..." with file names
    
    await _assetService.syncFolder('assets/images', onProgress: (path, progress) {
      if (mounted) {
        setState(() {
          _currentFile = path.split('/').last;
          // We can keep the filename as is, or format it.
          // Let's just show the status message + filename
          _statusMessage = '${LocalizationService().translate('resourceDownload.downloading')} ($_currentFile)';
        });
      }
    });

    await _assetService.syncFolder('assets/car_images', onProgress: (path, progress) {
      if (mounted) {
        setState(() {
          _currentFile = path.split('/').last;
          _statusMessage = '${LocalizationService().translate('resourceDownload.downloading')} ($_currentFile)';
        });
      }
    });

    if (!mounted) return;
    setState(() {
      _statusMessage = LocalizationService().translate('resourceDownload.ready');
      _progress = 1.0;
    });

    // Navigate to next screen
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 1)); // Show "Ready" for a second
    if (!mounted) return;

    final user = await AuthService().getCurrentUser();
    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Image.asset(
            'assets/images/splash_screen.jpeg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Progress Indicator at Bottom Center
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LocalizationService().translate('resourceDownload.title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      value: null, // Indeterminate for now as we don't know total size
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
