import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../models/user_model.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    setState(() => _isLoading = true);
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService().languageNotifier,
      builder: (context, currentLanguage, child) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text('store.title'.tr()),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentUser == null
                  ? const Center(child: Text('Kullanıcı bulunamadı'))
                  : RefreshIndicator(
                      onRefresh: _loadCurrentUser,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bakiye Kartı
                            _buildBalanceCard(),
                            const SizedBox(height: 24),
                            
                            // Altın Satın Alma Paketleri
                            _buildSectionTitle('store.buyGold'.tr()),
                            const SizedBox(height: 12),
                            _buildGoldPackages(),
                            
                            const SizedBox(height: 32),
                            
                            // Altın Bozdurma
                            _buildSectionTitle('store.convertGold'.tr()),
                            const SizedBox(height: 12),
                            _buildConvertGoldSection(),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade700, Colors.amber.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.monetization_on, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'store.yourGold'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_currentUser!.gold.toStringAsFixed(2)} ${'store.gold'.tr()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'home.balance'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_formatCurrency(_currentUser!.balance)} TL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildGoldPackages() {
    final packages = [
      {'gold': 1, 'price': 100, 'bonus': 0},
      {'gold': 5, 'price': 450, 'bonus': 50},
      {'gold': 10, 'price': 850, 'bonus': 150},
      {'gold': 25, 'price': 2000, 'bonus': 500},
    ];

    return Column(
      children: packages.map((package) {
        final gold = package['gold'] as int;
        final price = package['price'] as int;
        final bonus = package['bonus'] as int;
        final hasBonus = bonus > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: InkWell(
              onTap: () => _showPurchaseDialog(gold, price),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // İkon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber.shade400, Colors.amber.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.stars,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Bilgiler
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '$gold ${'store.gold'.tr()}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (hasBonus)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Text(
                                    '+$bonus TL ${'store.bonus'.tr()}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '≈ ${_formatCurrency(gold * 1000000.0)} ${'store.gameCurrency'.tr()}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Fiyat
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$price TL',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        Text(
                          'store.realMoney'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConvertGoldSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.currency_exchange,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'store.convertGoldTitle'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'store.convertGoldDesc'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'store.exchangeRate'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '1 ${'store.gold'.tr()} = 1.000.000 TL',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _currentUser!.gold > 0
                  ? () => _showConvertGoldDialog()
                  : null,
              icon: const Icon(Icons.swap_horiz),
              label: Text('store.convertNow'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ),
          if (_currentUser!.gold == 0) ...[
            const SizedBox(height: 8),
            Text(
              'store.needGoldToConvert'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  void _showPurchaseDialog(int gold, int price) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_cart, color: Colors.amber),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('store.purchaseGold'.tr())),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('store.package'.tr()),
                      Text(
                        '$gold ${'store.gold'.tr()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('store.price'.tr()),
                      Text(
                        '$price TL',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'store.paymentComingSoon'.tr(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('store.paymentSystemComingSoon'.tr()),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: Text('store.buy'.tr()),
          ),
        ],
      ),
    );
  }

  void _showConvertGoldDialog() {
    final maxGold = _currentUser!.gold; // Tüm altınları bozdurabilir (double)
    double selectedGold = 0.1; // 0.1'den başlasın
    
    final TextEditingController controller = TextEditingController(text: '0.1');
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String? validationError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.currency_exchange, color: Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('store.convertGold'.tr())),
                ],
              ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'store.selectAmount'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Input alanı + ve - butonları ile
                  Row(
                    children: [
                      // Azalt butonu (-)
                      IconButton(
                        onPressed: selectedGold > 0.1
                            ? () {
                                setDialogState(() {
                                  selectedGold = (selectedGold - 0.1).clamp(0.1, maxGold);
                                  selectedGold = double.parse(selectedGold.toStringAsFixed(1));
                                  controller.text = selectedGold.toStringAsFixed(1);
                                  validationError = _validateGoldAmount(controller.text, maxGold);
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 36),
                        color: Colors.deepPurple,
                        iconSize: 36,
                      ),
                      // Input (readonly)
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          readOnly: true, // Kullanıcı yazamasın
                          enableInteractiveSelection: false, // Context menu'yu kapat
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: validationError != null ? Colors.red : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            suffix: Text(
                              'store.gold'.tr(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            errorText: validationError,
                            errorMaxLines: 2,
                          ),
                          validator: (value) => _validateGoldAmount(value, maxGold),
                        ),
                      ),
                      // Arttır butonu (+)
                      IconButton(
                        onPressed: () {
                          setDialogState(() {
                            selectedGold = (selectedGold + 0.1).clamp(0.1, maxGold);
                            selectedGold = double.parse(selectedGold.toStringAsFixed(1));
                            controller.text = selectedGold.toStringAsFixed(1);
                            validationError = _validateGoldAmount(controller.text, maxGold);
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 36),
                        color: Colors.deepPurple,
                        iconSize: 36,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Hızlı seçim butonları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickSelectButton(
                        context,
                        '1',
                        1.0,
                        maxGold,
                        () {
                          setDialogState(() {
                            if (1.0 <= maxGold) {
                              selectedGold = 1.0;
                              controller.text = '1.0';
                              validationError = _validateGoldAmount(controller.text, maxGold);
                            }
                          });
                        },
                      ),
                      _buildQuickSelectButton(
                        context,
                        '5',
                        5.0,
                        maxGold,
                        () {
                          setDialogState(() {
                            if (5.0 <= maxGold) {
                              selectedGold = 5.0;
                              controller.text = '5.0';
                              validationError = _validateGoldAmount(controller.text, maxGold);
                            }
                          });
                        },
                      ),
                      _buildQuickSelectButton(
                        context,
                        '10',
                        10.0,
                        maxGold,
                        () {
                          setDialogState(() {
                            if (10.0 <= maxGold) {
                              selectedGold = 10.0;
                              controller.text = '10.0';
                              validationError = _validateGoldAmount(controller.text, maxGold);
                            }
                          });
                        },
                      ),
                      _buildQuickSelectButton(
                        context,
                        '25',
                        25.0,
                        maxGold,
                        () {
                          setDialogState(() {
                            if (25.0 <= maxGold) {
                              selectedGold = 25.0;
                              controller.text = '25.0';
                              validationError = _validateGoldAmount(controller.text, maxGold);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'store.availableGold'.tr() + ': ${maxGold.toStringAsFixed(2)} ${'store.gold'.tr()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Alacağınız Para
                        Text(
                          'store.youWillGet'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatCurrency(selectedGold * 1000000.0)} TL',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Divider(height: 24),
                        // Kalan Altın
                        Text(
                          'store.remainingGold'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(maxGold - selectedGold).toStringAsFixed(2)} ${'store.gold'.tr()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('common.cancel'.tr()),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      await _showConvertConfirmDialog(selectedGold);
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: Text('store.convert'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
        },
      ),
    );
  }

  // Hızlı seçim butonu widget'ı
  Widget _buildQuickSelectButton(
    BuildContext context,
    String label,
    double value,
    double maxGold,
    VoidCallback onTap,
  ) {
    final isDisabled = value > maxGold;
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: isDisabled ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDisabled ? Colors.grey[300] : Colors.amber[600],
            foregroundColor: isDisabled ? Colors.grey[600] : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: isDisabled ? 0 : 2,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String? _validateGoldAmount(String? value, double maxGold) {
    if (value == null || value.isEmpty) {
      return 'store.enterAmount'.tr();
    }

    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'store.invalidNumber'.tr();
    }

    if (parsed < 0.1) {
      return 'En az 0.1 altın girmelisiniz';
    }

    if (parsed > maxGold) {
      return 'Yetersiz altın! Mevcut: ${maxGold.toStringAsFixed(1)} altın';
    }

    return null;
  }

  Future<void> _showConvertConfirmDialog(double gold) async {
    final gameCurrency = gold * 1000000.0;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('store.confirmConvert'.tr())),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'store.confirmConvertMessage'.tr(),
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'store.goldAmount'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${gold.toStringAsFixed(2)} ${'store.gold'.tr()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'store.youWillGet'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${_formatCurrency(gameCurrency)} TL',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: Text('store.confirmButton'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _convertGold(gold);
    }
  }

  Future<void> _convertGold(double gold) async {
    try {
      final gameCurrency = gold * 1000000.0;
      final newGold = _currentUser!.gold - gold;
      final newBalance = _currentUser!.balance + gameCurrency;

      await _db.updateUser(_currentUser!.id, {
        'gold': newGold,
        'balance': newBalance,
      });

      await _loadCurrentUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${gold.toStringAsFixed(2)} ${'store.gold'.tr()} → ${_formatCurrency(gameCurrency)} TL',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('store.convertError'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

