// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/asset_service.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class ResourceDownloadScreen extends StatefulWidget {
  const ResourceDownloadScreen({super.key});

  @override
  State<ResourceDownloadScreen> createState() => _ResourceDownloadScreenState();
}

class _ResourceDownloadScreenState extends State<ResourceDownloadScreen> {
  final AssetService _assetService = AssetService();
  double _progress = 0.0;
  String _timeRemaining = '';
  int _totalFiles = 0;
  int _downloadedFiles = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDownload();
    });
  }

  String _formatDurationShort(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Future<void> _startDownload() async {
    setState(() {});

    await _assetService.init();

    if (!mounted) return;

    // 1. Get all file paths first
    List<String> allPaths = [];
    allPaths.addAll(await _assetService.getAllFilePaths('assets/images'));
    allPaths.addAll(await _assetService.getAllFilePaths('assets/car_images'));
    allPaths.addAll(
      await _assetService.getAllFilePaths('assets/images/brands'),
    );

    _totalFiles = allPaths.length;

    if (_totalFiles == 0) {
      _finishDownload();
      return;
    }

    setState(() {
      _startTime = DateTime.now();
    });

    // 2. Filter out already downloaded files (optional optimization, but good for progress accuracy)
    // Actually, let's just check them as we go, or check beforehand.
    // checking beforehand might take time.
    // Let's check beforehand to know exactly how many *need* downloading for accurate time estimation.
    // But `isAssetDownloaded` is async.
    // Let's just iterate and download. If it exists, `downloadAsset` might overwrite or we check `isAssetDownloaded` inside loop.
    // `AssetService.syncFolder` checks `isAssetDownloaded`.

    // Let's do a smart queue.
    // We can process in chunks of 5.

    int chunkSize = 5;
    for (int i = 0; i < allPaths.length; i += chunkSize) {
      if (!mounted) return;

      int end = (i + chunkSize < allPaths.length)
          ? i + chunkSize
          : allPaths.length;
      List<String> chunk = allPaths.sublist(i, end);

      await Future.wait(
        chunk.map((path) async {
          bool exists = await _assetService.isAssetDownloaded(path);
          if (!exists) {
            await _assetService.downloadAsset(path);
          }
          _updateProgress();
        }),
      );
    }

    _finishDownload();
  }

  void _updateProgress() {
    if (!mounted) return;

    _downloadedFiles++;
    double progress = _downloadedFiles / _totalFiles;

    // Calculate time remaining
    if (_startTime != null && _downloadedFiles > 0) {
      final elapsed = DateTime.now().difference(_startTime!);
      final avgTimePerFile = elapsed.inMilliseconds / _downloadedFiles;
      final remainingFiles = _totalFiles - _downloadedFiles;
      final remainingMillis = avgTimePerFile * remainingFiles;
      final remainingDuration = Duration(milliseconds: remainingMillis.toInt());

      setState(() {
        _progress = progress;
        _timeRemaining = _formatDurationShort(remainingDuration);
      });
    } else {
      setState(() {
        _progress = progress;
      });
    }
  }

  void _finishDownload() {
    if (!mounted) return;
    setState(() {
      _progress = 1.0;
      _timeRemaining = '';
    });
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(
      const Duration(seconds: 1),
    ); // Show "Ready" for a second
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
                      fontSize: 18,
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

                  // Progress Info (Percentage and Time)
                  if (_progress < 1.0 && _progress > 0.0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 5, color: Colors.black),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          if (_timeRemaining.isNotEmpty)
                            Text(
                              _timeRemaining,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(blurRadius: 5, color: Colors.black),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: 250,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.amber,
                        ),
                      ),
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
