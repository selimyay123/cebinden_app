import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class AssetService {
  static final AssetService _instance = AssetService._internal();
  factory AssetService() => _instance;
  AssetService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Dio _dio = Dio();
  
  String? _localPath;

  Future<void> init() async {
    final docDir = await getApplicationDocumentsDirectory();
    _localPath = '${docDir.path}/game_assets';
    final dir = Directory(_localPath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  String get localPath => _localPath!;

  File getLocalFile(String assetPath) {
    // assetPath example: assets/images/home_bg.png
    return File('$_localPath/$assetPath');
  }

  Future<bool> isAssetDownloaded(String assetPath) async {
    final file = getLocalFile(assetPath);
    return await file.exists();
  }

  /// Downloads a file from Firebase Storage to local storage
  /// Returns true if successful
  Future<bool> downloadAsset(String assetPath, {Function(double)? onProgress}) async {
    try {
      final ref = _storage.ref().child(assetPath);
      final downloadUrl = await ref.getDownloadURL();
      final file = getLocalFile(assetPath);
      
      // Ensure directory exists
      await file.parent.create(recursive: true);

      await _dio.download(
        downloadUrl,
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error downloading asset $assetPath: $e');
      return false;
    }
  }

  /// Lists all files in a folder in Firebase Storage (shallow)
  Future<List<String>> listAssets(String folderPath) async {
    try {
      final result = await _storage.ref().child(folderPath).listAll();
      List<String> paths = [];
      
      for (var item in result.items) {
        paths.add(item.fullPath);
      }
      
      for (var prefix in result.prefixes) {
        // Recursively list subfolders if needed, or just return folders
        // For now, let's just add the folder logic in the main downloader
        // paths.addAll(await listAssets(prefix.fullPath)); 
      }
      
      return paths;
    } catch (e) {
      debugPrint('Error listing assets in $folderPath: $e');
      return [];
    }
  }

  /// Recursively gets all file paths in a folder
  Future<List<String>> getAllFilePaths(String folderPath) async {
    try {
      final ref = _storage.ref().child(folderPath);
      final result = await ref.listAll();
      List<String> paths = [];

      for (var item in result.items) {
        paths.add(item.fullPath);
      }

      for (var prefix in result.prefixes) {
        paths.addAll(await getAllFilePaths(prefix.fullPath));
      }
      
      return paths;
    } catch (e) {
      debugPrint('Error listing assets in $folderPath: $e');
      return [];
    }
  }

  /// Recursively downloads all assets in a folder
  Future<void> syncFolder(String folderPath, {Function(String, double)? onProgress}) async {
    try {
      final ref = _storage.ref().child(folderPath);
      final result = await ref.listAll();
      // ... existing implementation ...
      // Note: We might not use this anymore in the new flow, but keeping it for compatibility
      // or we can refactor it to use getAllFilePaths if we wanted, but the plan says
      // we will refactor _startDownload in the screen, so I'll leave this as is for now
      // unless I want to make it cleaner.
      // Actually, let's just add the new method and leave syncFolder as is for now.
      
      for (var item in result.items) {
        final path = item.fullPath;
        if (!await isAssetDownloaded(path)) {
          if (onProgress != null) onProgress(path, 0.0);
          await downloadAsset(path, onProgress: (p) {
             if (onProgress != null) onProgress(path, p);
          });
        }
      }

      for (var prefix in result.prefixes) {
        await syncFolder(prefix.fullPath, onProgress: onProgress);
      }
    } catch (e) {
      debugPrint('Error syncing folder $folderPath: $e');
    }
  }
}
