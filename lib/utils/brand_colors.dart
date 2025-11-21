import 'package:flutter/material.dart';

/// Marka renkleri - Tek bir yerden yönetim
class BrandColors {
  static final Map<String, Color> colors = {
    'Audira': Colors.grey[800]!,
    'Bavora': Colors.blue[700]!,
    'Citronix': Colors.red[400]!,
    'Fialto': Colors.red[600]!,
    'Fortran': Colors.blue[900]!,
    'Hyundaro': Colors.grey[700]!,
    'Hondaro': Colors.red[700]!,
    'Mercurion': Colors.grey[600]!,
    'Opexel': Colors.yellow[700]!,
    'Peugot': Colors.blue[800]!,
    'Renauva': Colors.yellow[800]!,
    'Skodra': Colors.green[700]!,
    'Toyoto': Colors.red[600]!,
    'Voltswagen': Colors.blue[700]!,
  };

  /// Marka rengini al, eğer yoksa varsayılan renk döndür
  static Color getColor(String brand, {Color defaultColor = Colors.deepPurple}) {
    return colors[brand] ?? defaultColor;
  }
}

