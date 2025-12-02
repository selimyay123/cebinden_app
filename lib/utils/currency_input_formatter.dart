import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    double value = double.parse(newValue.text.replaceAll('.', ''));
    final formatter = NumberFormat('#,###', 'tr_TR');
    String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
  
  static String format(double value) {
    final formatter = NumberFormat('#,###', 'tr_TR');
    return formatter.format(value);
  }
  
  static double parse(String text) {
    return double.tryParse(text.replaceAll('.', '')) ?? 0;
  }
}
