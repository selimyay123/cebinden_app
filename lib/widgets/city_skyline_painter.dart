import 'dart:math';
import 'package:flutter/material.dart';

class CitySkylinePainter extends CustomPainter {
  final Color color;

  CitySkylinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final random = Random(42); // Sabit seed ile her seferinde aynı şehir
    double currentX = 0;

    final path = Path();
    path.moveTo(0, size.height);

    while (currentX < size.width) {
      final buildingWidth = 20.0 + random.nextDouble() * 40.0;
      final buildingHeight = 20.0 + random.nextDouble() * (size.height * 0.6);

      // Bina çiz
      path.lineTo(currentX, size.height - buildingHeight);
      path.lineTo(currentX + buildingWidth, size.height - buildingHeight);
      
      // Çatı detayları (opsiyonel)
      if (random.nextBool()) {
        // Düz çatı, bir şey yapma
      } else if (random.nextBool()) {
        // Üçgen çatı / Anten
        path.lineTo(currentX + buildingWidth / 2, size.height - buildingHeight - 10);
        path.lineTo(currentX + buildingWidth, size.height - buildingHeight);
      }

      currentX += buildingWidth;
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
    
    // Pencereler (Işıklar)
    final windowPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
      
    // Tekrar başa dön ve pencereleri çiz
    currentX = 0;
    final randomWindows = Random(42);
    
    while (currentX < size.width) {
      final buildingWidth = 20.0 + randomWindows.nextDouble() * 40.0;
      final buildingHeight = 20.0 + randomWindows.nextDouble() * (size.height * 0.6);
      
      // Binanın içine rastgele pencereler
      if (buildingHeight > 40) {
        int floors = (buildingHeight / 15).floor();
        int windowsPerFloor = (buildingWidth / 10).floor();
        
        for (int i = 0; i < floors; i++) {
          for (int j = 0; j < windowsPerFloor; j++) {
            if (randomWindows.nextDouble() > 0.6) { // %40 şansla ışık yanıyor
              canvas.drawRect(
                Rect.fromLTWH(
                  currentX + 4 + (j * 8), 
                  size.height - buildingHeight + 10 + (i * 12), 
                  4, 
                  6
                ), 
                windowPaint
              );
            }
          }
        }
      }
      
      currentX += buildingWidth;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
