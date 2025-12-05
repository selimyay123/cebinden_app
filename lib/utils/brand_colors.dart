import 'package:flutter/material.dart';

/// Marka renkleri - Tek bir yerden yönetim
class BrandColors {
  static final Map<String, Color> colors = {
    'Audira': Colors.grey[800]!,
    'Bavora': Colors.blue[700]!,
    'Citronix': Colors.red[400]!,
    'Fialto': Colors.red[600]!,
    'Fortran': Colors.blue[900]!,
    'Hundar': Colors.grey[700]!,
    'Hanto': Colors.red[700]!,
    'Mercurion': Colors.grey[600]!,
    'Oplon': Colors.yellow[700]!,
    'Peugot': Colors.blue[800]!,
    'Renauva': Colors.yellow[800]!,
    'Skodra': Colors.green[700]!,
    'Koyoro': Colors.red[900]!,
    'Volkstar': Colors.blue[700]!,
  };

  /// Marka rengini al, eğer yoksa varsayılan renk döndür
  static Color getColor(String brand, {Color defaultColor = Colors.deepPurple}) {
    return colors[brand] ?? defaultColor;
  }
}

