import 'dart:io';
import 'package:flutter/material.dart';
import '../services/asset_service.dart';

class GameImage extends StatefulWidget {
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
  State<GameImage> createState() => _GameImageState();
}

class _GameImageState extends State<GameImage> {
  bool _isLoading = false;
  // ignore: unused_field
  bool _hasError = false;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _checkFile();
  }

  @override
  void didUpdateWidget(GameImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _checkFile();
    }
  }

  Future<void> _checkFile() async {
    if (!mounted) return;

    final file = AssetService().getLocalFile(widget.assetPath);
    if (file.existsSync()) {
      if (mounted) {
        setState(() {
          _localFile = file;
          _isLoading = false;
          _hasError = false;
        });
      }
    } else {
      // Dosya yok, indirmeyi dene
      // Sadece belirli klasörler için otomatik indirme yap
      if (widget.assetPath.startsWith('assets/car_images') ||
          widget.assetPath.startsWith('assets/images/brands')) {
        _downloadFile();
      } else {
        // Diğer assetler için fallback (bundle asset)
        if (mounted) {
          setState(() {
            _localFile = null;
            _isLoading = false;
            _hasError = false; // Asset bundle'dan deneyecek
          });
        }
      }
    }
  }

  Future<void> _downloadFile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    final success = await AssetService().downloadAsset(widget.assetPath);

    if (!mounted) return;

    if (success) {
      final file = AssetService().getLocalFile(widget.assetPath);
      setState(() {
        _localFile = file;
        _isLoading = false;
        _hasError = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_localFile != null) {
      return Image.file(
        _localFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        alignment: widget.alignment,
        repeat: widget.repeat,
        centerSlice: widget.centerSlice,
        matchTextDirection: widget.matchTextDirection,
        gaplessPlayback: widget.gaplessPlayback,
        isAntiAlias: widget.isAntiAlias,
        filterQuality: widget.filterQuality,
        errorBuilder: (context, error, stackTrace) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context, error, stackTrace);
          }
          // Fallback to asset if file is corrupted
          return Image.asset(
            widget.assetPath,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            color: widget.color,
            colorBlendMode: widget.colorBlendMode,
            alignment: widget.alignment,
            repeat: widget.repeat,
            centerSlice: widget.centerSlice,
            matchTextDirection: widget.matchTextDirection,
            gaplessPlayback: widget.gaplessPlayback,
            isAntiAlias: widget.isAntiAlias,
            filterQuality: widget.filterQuality,
            errorBuilder: widget.errorBuilder,
          );
        },
      );
    } else {
      // Fallback to asset if not downloaded yet or failed
      return Image.asset(
        widget.assetPath,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        alignment: widget.alignment,
        repeat: widget.repeat,
        centerSlice: widget.centerSlice,
        matchTextDirection: widget.matchTextDirection,
        gaplessPlayback: widget.gaplessPlayback,
        isAntiAlias: widget.isAntiAlias,
        filterQuality: widget.filterQuality,
        errorBuilder:
            widget.errorBuilder ??
            (context, error, stackTrace) {
              return Container(
                width: widget.width,
                height: widget.height,
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
    super.fit,
    super.alignment,
    super.repeat,
    super.centerSlice,
    super.matchTextDirection,
    bool gaplessPlayback = false,
    super.filterQuality = FilterQuality.low,
    super.invertColors,
    super.isAntiAlias,
    super.scale,
    super.opacity,
    super.colorFilter,
  }) : super(image: _getImageProvider(assetPath));

  static ImageProvider _getImageProvider(String assetPath) {
    final file = AssetService().getLocalFile(assetPath);
    if (file.existsSync()) {
      return FileImage(file);
    } else {
      return AssetImage(assetPath);
    }
  }
}
