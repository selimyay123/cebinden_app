import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';

class ChangeUsernameScreen extends StatefulWidget {
  final String userId;
  final String currentUsername;

  const ChangeUsernameScreen({
    super.key,
    required this.userId,
    required this.currentUsername,
  });

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper();

  bool _isLoading = false;
  String? _errorMessage;
  User? _user;
  bool _canChange = false;
  String _statusMessage = '';
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.currentUsername;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final userMap = await _db.getUserById(widget.userId);
    if (userMap != null) {
      _user = User.fromJson(userMap);
      _checkEligibility();
    }
    setState(() => _isLoading = false);
  }

  void _checkEligibility() {
    if (_user == null) return;

    if (_user!.usernameChangeCount == 0) {
      _canChange = true;
      _statusMessage = 'changeUsername.firstChangeFree'.tr();
      _statusColor = Colors.green;
    } else {
      if (_user!.lastUsernameChangeDate != null) {
        final daysSinceLastChange = DateTime.now()
            .difference(_user!.lastUsernameChangeDate!)
            .inDays;
        if (daysSinceLastChange >= 7) {
          _canChange = true;
          _statusMessage = 'changeUsername.changeAvailable'.tr();
          _statusColor = Colors.green;
        } else {
          _canChange = false;
          final daysRemaining = 7 - daysSinceLastChange;
          _statusMessage = 'changeUsername.nextChangeAvailable'.trParams({
            'days': daysRemaining.toString(),
          });
          _statusColor = Colors.red;
        }
      } else {
        // Should not happen if count > 0, but fallback
        _canChange = true;
        _statusMessage = 'changeUsername.changeAvailable'.tr();
        _statusColor = Colors.green;
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _changeUsername() async {
    if (!_canChange) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final newUsername = _usernameController.text.trim();

    // Validations
    if (newUsername.isEmpty) {
      setState(() {
        _errorMessage = 'changeUsername.enterNewUsername'.tr();
        _isLoading = false;
      });
      return;
    }

    if (newUsername.length < 3) {
      setState(() {
        _errorMessage = 'auth.usernameMinLength'.tr();
        _isLoading = false;
      });
      return;
    }

    // Küfür kontrolü
    if (_authService.hasProfanity(newUsername)) {
      setState(() {
        _errorMessage = 'auth.usernameProfanity'.tr();
        _isLoading = false;
      });
      return;
    }

    if (newUsername == widget.currentUsername) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Change username
    final success = await _authService.changeUsername(
      userId: widget.userId,
      newUsername: newUsername,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), 
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          content: Text('changeUsername.success'.tr()),
          backgroundColor: Colors.green.withOpacity(0.8),
        ),
      );
      Navigator.pop(context, true); // Return true to indicate success
    } else {
      setState(() {
        _errorMessage = 'changeUsername.usernameTaken'.tr();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('changeUsername.title'.tr()),
        actions: [],
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading && _user == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon
                    Icon(
                      Icons.person_outline,
                      size: 80,
                      color: Colors.deepPurple.withOpacity(0.7),
                    ),
                    const SizedBox(height: 20),

                    // Başlık
                    Text(
                      'changeUsername.title'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Durum Mesajı
                    if (_statusMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),

                    // Hata Mesajı
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Yeni Kullanıcı Adı
                    TextField(
                      controller: _usernameController,
                      maxLength: 10,
                      enabled: _canChange,
                      decoration: InputDecoration(
                        labelText: 'changeUsername.newUsername'.tr(),
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Kaydet Butonu
                    ElevatedButton(
                      onPressed: _isLoading || !_canChange
                          ? null
                          : _changeUsername,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'common.save'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
