import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';

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
    Widget image = (vehicle.brand == 'Renauva' && vehicle.model == 'Slim')
        ? Image.asset(
            'assets/car_images/Renauva/Slim_fixed.png',
            width: width,
            height: height,
            fit: fit,
          )
        : Image.asset(
            vehicle.imageUrl!,
            width: width,
            height: height,
            fit: fit,
          );

    // Sadece Renauva Slim için maske tabanlı boyama uygula
    if (vehicle.brand == 'Renauva' && vehicle.model == 'Slim') {
      final color = _getVehicleColor(vehicle.color);
      if (color != null) {
        return Stack(
          children: [
            image, // Orijinal resim (alt katman)
            Positioned.fill(
              child: ColorFiltered(
                // 2. Adım: Maskeyi istenen renge boya
                colorFilter: ColorFilter.mode(
                  color.withOpacity(0.6), 
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
                  child: Image.asset(
                    'assets/car_images/Renauva/Slim_mask_fixed.png',
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
