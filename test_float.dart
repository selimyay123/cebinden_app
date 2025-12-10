void main() {
  double purchasePrice = 200000;
  double maxPrice = (purchasePrice * 1.15).roundToDouble();
  double inputPrice = 230000;
  
  print('Purchase Price: $purchasePrice');
  print('Max Price: $maxPrice');
  print('Input Price: $inputPrice');
  print('Input > Max: ${inputPrice > maxPrice}');
  print('Max Price Raw: ${maxPrice.toStringAsPrecision(20)}');
}
