import 'dart:io';
import 'package:flutter/material.dart';
import '../services/asset_service.dart';

class GameImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final Map<String, String>? headers;
  final ImageErrorWidgetBuilder? errorBuilder;

  const GameImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.colorBlendMode,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    this.headers,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final file = AssetService().getLocalFile(assetPath);
    
    if (file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        color: color,
        colorBlendMode: colorBlendMode,
        alignment: alignment,
        repeat: repeat,
        centerSlice: centerSlice,
        matchTextDirection: matchTextDirection,
        gaplessPlayback: gaplessPlayback,
        isAntiAlias: isAntiAlias,
        filterQuality: filterQuality,
        errorBuilder: (context, error, stackTrace) {
          if (errorBuilder != null) {
             return errorBuilder!(context, error, stackTrace);
          }
          // Fallback to asset if file is corrupted
          return Image.asset(
            assetPath,
            width: width,
            height: height,
            fit: fit,
            color: color,
            colorBlendMode: colorBlendMode,
            alignment: alignment,
            repeat: repeat,
            centerSlice: centerSlice,
            matchTextDirection: matchTextDirection,
            gaplessPlayback: gaplessPlayback,
            isAntiAlias: isAntiAlias,
            filterQuality: filterQuality,
            errorBuilder: errorBuilder,
          );
        },
      );
    } else {
      // Fallback to asset if not downloaded yet
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        color: color,
        colorBlendMode: colorBlendMode,
        alignment: alignment,
        repeat: repeat,
        centerSlice: centerSlice,
        matchTextDirection: matchTextDirection,
        gaplessPlayback: gaplessPlayback,
        isAntiAlias: isAntiAlias,
        filterQuality: filterQuality,
        errorBuilder: errorBuilder ?? (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: Icon(Icons.image_not_supported, color: Colors.grey[500]),
          );
        },
      );
    }
  }
}

/// Helper for DecorationImage
class GameDecorationImage extends DecorationImage {
  GameDecorationImage({
    required String assetPath,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = false,
    FilterQuality filterQuality = FilterQuality.low,
    bool invertColors = false,
    bool isAntiAlias = false,
    double scale = 1.0,
    double opacity = 1.0,
    ColorFilter? colorFilter,
  }) : super(
          image: _getImageProvider(assetPath),
          fit: fit,
          alignment: alignment,
          repeat: repeat,
          centerSlice: centerSlice,
          matchTextDirection: matchTextDirection,
          filterQuality: filterQuality,
          invertColors: invertColors,
          isAntiAlias: isAntiAlias,
          scale: scale,
          opacity: opacity,
          colorFilter: colorFilter,
        );

  static ImageProvider _getImageProvider(String assetPath) {
    final file = AssetService().getLocalFile(assetPath);
    if (file.existsSync()) {
      return FileImage(file);
    } else {
      return AssetImage(assetPath);
    }
  }
}
