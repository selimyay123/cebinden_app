import 'package:flutter/material.dart';
import '../services/localization_service.dart';

/// Araç üstten bakış görseli
/// Boyalı veya değişen parçaları gösterir
class VehicleTopView extends StatelessWidget {
  final Map<String, String> partConditions;
  final double width;
  final double height;

  const VehicleTopView({
    super.key,
    required this.partConditions,
    this.width = 250,
    this.height = 400,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Araç görseli
        CustomPaint(
          size: Size(width, height),
          painter: _VehicleTopViewPainter(
            partConditions: partConditions,
          ),
        ),
        const SizedBox(height: 16),
        // Lejant
        _buildLegend(),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildLegendItem('vehicleParts.original'.tr(), Colors.grey[400]!),
        _buildLegendItem('vehicleParts.localPainted'.tr(), Colors.orange[200]!),
        _buildLegendItem('vehicleParts.painted'.tr(), Colors.blue[300]!),
        _buildLegendItem('vehicleParts.replaced'.tr(), Colors.red[300]!),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.grey[600]!),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VehicleTopViewPainter extends CustomPainter {
  final Map<String, String> partConditions;

  _VehicleTopViewPainter({
    required this.partConditions,
  });

  Color _getPartColor(String partName) {
    final condition = partConditions[partName] ?? 'orijinal';
    switch (condition) {
      case 'orijinal':
        return Colors.grey[400]!;
      case 'lokal_boyali':
        return Colors.orange[200]!;
      case 'boyali':
        return Colors.blue[300]!;
      case 'degisen':
        return Colors.red[300]!;
      default:
        return Colors.grey[400]!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final wheelPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // Kaput (ön)
    final hoodPaint = Paint()
      ..color = _getPartColor('kaput')
      ..style = PaintingStyle.fill;
    final hoodRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.35,
        size.height * 0.05,
        size.width * 0.3,
        size.height * 0.12,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(hoodRect, hoodPaint);
    canvas.drawRRect(hoodRect, strokePaint);

    // Ön Sol Çamurluk
    final frontLeftFenderPaint = Paint()
      ..color = _getPartColor('sol_on_camurluk')
      ..style = PaintingStyle.fill;
    final frontLeftFenderPath = Path()
      ..moveTo(size.width * 0.2, size.height * 0.12)
      ..lineTo(size.width * 0.35, size.height * 0.05)
      ..lineTo(size.width * 0.35, size.height * 0.22)
      ..lineTo(size.width * 0.25, size.height * 0.28)
      ..close();
    canvas.drawPath(frontLeftFenderPath, frontLeftFenderPaint);
    canvas.drawPath(frontLeftFenderPath, strokePaint);

    // Ön Sağ Çamurluk
    final frontRightFenderPaint = Paint()
      ..color = _getPartColor('sag_on_camurluk')
      ..style = PaintingStyle.fill;
    final frontRightFenderPath = Path()
      ..moveTo(size.width * 0.8, size.height * 0.12)
      ..lineTo(size.width * 0.65, size.height * 0.05)
      ..lineTo(size.width * 0.65, size.height * 0.22)
      ..lineTo(size.width * 0.75, size.height * 0.28)
      ..close();
    canvas.drawPath(frontRightFenderPath, frontRightFenderPaint);
    canvas.drawPath(frontRightFenderPath, strokePaint);

    // Sol Ön Kapı
    final frontLeftDoorPaint = Paint()
      ..color = _getPartColor('sol_on_kapi')
      ..style = PaintingStyle.fill;
    final frontLeftDoorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.30,
        size.width * 0.08,
        size.height * 0.17,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(frontLeftDoorRect, frontLeftDoorPaint);
    canvas.drawRRect(frontLeftDoorRect, strokePaint);

    // Sağ Ön Kapı
    final frontRightDoorPaint = Paint()
      ..color = _getPartColor('sag_on_kapi')
      ..style = PaintingStyle.fill;
    final frontRightDoorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.70,
        size.height * 0.30,
        size.width * 0.08,
        size.height * 0.17,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(frontRightDoorRect, frontRightDoorPaint);
    canvas.drawRRect(frontRightDoorRect, strokePaint);

    // Tavan (ortadaki gövde)
    final roofPaint = Paint()
      ..color = _getPartColor('tavan')
      ..style = PaintingStyle.fill;
    final roofRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.30,
        size.height * 0.22,
        size.width * 0.40,
        size.height * 0.32,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(roofRect, roofPaint);
    canvas.drawRRect(roofRect, strokePaint);

    // Sol Arka Kapı
    final rearLeftDoorPaint = Paint()
      ..color = _getPartColor('sol_arka_kapi')
      ..style = PaintingStyle.fill;
    final rearLeftDoorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.53,
        size.width * 0.08,
        size.height * 0.17,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(rearLeftDoorRect, rearLeftDoorPaint);
    canvas.drawRRect(rearLeftDoorRect, strokePaint);

    // Sağ Arka Kapı
    final rearRightDoorPaint = Paint()
      ..color = _getPartColor('sag_arka_kapi')
      ..style = PaintingStyle.fill;
    final rearRightDoorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.70,
        size.height * 0.53,
        size.width * 0.08,
        size.height * 0.17,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(rearRightDoorRect, rearRightDoorPaint);
    canvas.drawRRect(rearRightDoorRect, strokePaint);

    // Arka Sol Çamurluk
    final rearLeftFenderPaint = Paint()
      ..color = _getPartColor('sol_arka_camurluk')
      ..style = PaintingStyle.fill;
    final rearLeftFenderPath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.72)
      ..lineTo(size.width * 0.35, size.height * 0.78)
      ..lineTo(size.width * 0.35, size.height * 0.95)
      ..lineTo(size.width * 0.20, size.height * 0.88)
      ..close();
    canvas.drawPath(rearLeftFenderPath, rearLeftFenderPaint);
    canvas.drawPath(rearLeftFenderPath, strokePaint);

    // Arka Sağ Çamurluk
    final rearRightFenderPaint = Paint()
      ..color = _getPartColor('sag_arka_camurluk')
      ..style = PaintingStyle.fill;
    final rearRightFenderPath = Path()
      ..moveTo(size.width * 0.75, size.height * 0.72)
      ..lineTo(size.width * 0.65, size.height * 0.78)
      ..lineTo(size.width * 0.65, size.height * 0.95)
      ..lineTo(size.width * 0.80, size.height * 0.88)
      ..close();
    canvas.drawPath(rearRightFenderPath, rearRightFenderPaint);
    canvas.drawPath(rearRightFenderPath, strokePaint);

    // Bagaj (arka)
    final trunkPaint = Paint()
      ..color = _getPartColor('bagaj')
      ..style = PaintingStyle.fill;
    final trunkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.35,
        size.height * 0.83,
        size.width * 0.3,
        size.height * 0.12,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(trunkRect, trunkPaint);
    canvas.drawRRect(trunkRect, strokePaint);

    // Tekerlekler
    final wheelRadius = size.width * 0.065;

    // Sol ön tekerlek
    _drawWheel(
      canvas,
      Offset(size.width * 0.18, size.height * 0.24),
      wheelRadius,
      wheelPaint,
    );

    // Sağ ön tekerlek
    _drawWheel(
      canvas,
      Offset(size.width * 0.82, size.height * 0.24),
      wheelRadius,
      wheelPaint,
    );

    // Sol arka tekerlek
    _drawWheel(
      canvas,
      Offset(size.width * 0.18, size.height * 0.76),
      wheelRadius,
      wheelPaint,
    );

    // Sağ arka tekerlek
    _drawWheel(
      canvas,
      Offset(size.width * 0.82, size.height * 0.76),
      wheelRadius,
      wheelPaint,
    );
  }

  void _drawWheel(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    
    // Jant detayı
    final rimPaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
