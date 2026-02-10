import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';
import 'game_image.dart';

class VehicleImage extends StatelessWidget {
  final Vehicle vehicle;
  final double? width;
  final double? height;
  final BoxFit fit;

  const VehicleImage({
    super.key,
    required this.vehicle,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // Renauva modelleri için sabitlenmiş (fixed) görselleri kullan
    bool isRenauvaCustom = (vehicle.brand == 'Renauva' && (vehicle.model == 'Slim'));
    
    String imagePath = vehicle.imageUrl!;
    // Legacy path fix for existing saved vehicles
    if (imagePath.endsWith('Renauva/Slim.png') || imagePath.endsWith('Renauva/Slim_test.png')) {
      imagePath = 'assets/car_images/renauva/slim/slim_1.png';
    } else if (imagePath.endsWith('Renauva/Magna.png')) {
      imagePath = 'assets/car_images/renauva/magna/magna_1.png';
    } else if (imagePath.endsWith('Renauva/Flow.png')) {
      imagePath = 'assets/car_images/renauva/flow/flow_1.png';
    } else if (imagePath.endsWith('Renauva/Signa.png')) {
      imagePath = 'assets/car_images/renauva/signa/signa_1.png';
    } else if (imagePath.endsWith('Renauva/Tallion.png')) {
      imagePath = 'assets/car_images/renauva/tallion/tallion_1.png';
    }

    Widget image = GameImage(
      assetPath: imagePath,
      width: width,
      height: height,
      fit: fit,
    );

    // Renauva modelleri için maske tabanlı boyama uygula
    // TEST: Slim için maskelemeyi devre dışı bırak (çünkü yeni görselin maskesi yok)
    if (isRenauvaCustom && vehicle.model != 'Slim') {
      final color = _getVehicleColor(vehicle.color);
      if (color != null) {
        String maskName = (vehicle.model == 'Slim') ? 'Slim_mask_fixed.png' : 'Signa_mask_fixed.png';
        
        return Stack(
          children: [
            image, // Orijinal resim (alt katman)
            Positioned.fill(
              child: ColorFiltered(
                // 2. Adım: Maskeyi istenen renge boya
                colorFilter: ColorFilter.mode(
                  color.withValues(alpha: 0.85), 
                  BlendMode.srcIn,
                ),
                child: ColorFiltered(
                  // 1. Adım: Siyah/Beyaz maskeyi Şeffaf/Beyaz'a çevir
                  colorFilter: const ColorFilter.matrix([
                    1, 0, 0, 0, 0,
                    0, 1, 0, 0, 0,
                    0, 0, 1, 0, 0,
                    1, 0, 0, 0, 0, // Alpha = Red kanalı
                  ]),
                  child: GameImage(
                    assetPath: 'assets/car_images/Renauva/$maskName',
                    width: width,
                    height: height,
                    fit: fit,
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    return image;
  }

  Color? _getVehicleColor(String colorName) {
    switch (colorName) {
      case 'Beyaz':
        return null;
      case 'Siyah':
        return Colors.black;
      case 'Gri':
        return Colors.grey;
      case 'Kırmızı':
        return const Color(0xFFD32F2F);
      case 'Mavi':
        return const Color(0xFF1976D2);
      case 'Gümüş':
        return const Color(0xFFB0BEC5);
      case 'Kahverengi':
        return const Color(0xFF795548);
      case 'Yeşil':
        return const Color(0xFF388E3C);
      default:
        return null;
    }
  }
}
