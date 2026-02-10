// Mock Localization
// ignore_for_file: unused_local_variable, unused_element

Map<String, String> tr = {
  'common.money_suffix_m': 'M',
  'common.money_suffix_b': 'B',
  'common.money_prefix_less_than': '<',
};

String getTr(String key) => tr[key] ?? key;

String _formatMoney(dynamic amount) {
  if (amount == null) return '0';

  // Ensure amount is treated as a number
  double value;
  if (amount is int) {
    value = amount.toDouble();
  } else if (amount is double) {
    value = amount;
  } else if (amount is String) {
    value = double.tryParse(amount) ?? 0;
  } else {
    return '0';
  }

  if (value < 1000000) {
    return '${getTr('common.money_prefix_less_than')}1${getTr('common.money_suffix_m')}';
  } else if (value < 1000000000) {
    int millions = (value / 1000000).floor();
    return '$millions${getTr('common.money_suffix_m')}';
  } else {
    int billions = (value / 1000000000).floor();
    return '$billions${getTr('common.money_suffix_b')}';
  }
}

void main() {
  var cases = [
    500,
    999999,
    1000000,
    1500000,
    2000000,
    154265221,
    999999999,
    1000000000,
    2500000000,
    '5000000',
    null,
  ];

  for (var c in cases) {}
}
