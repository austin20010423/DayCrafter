import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local authentication service for user registration and login
class LocalAuthService {
  static const String _accountsKey = 'local_accounts';
  static const String _currentUserKey = 'current_user_email';

  /// Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get all registered accounts
  Future<List<Map<String, dynamic>>> _getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_accountsKey);
    if (accountsJson == null) return [];

    final List<dynamic> accounts = jsonDecode(accountsJson);
    return accounts.cast<Map<String, dynamic>>();
  }

  /// Save accounts to SharedPreferences
  Future<void> _saveAccounts(List<Map<String, dynamic>> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }

  /// Check if an email is already registered
  Future<bool> isEmailRegistered(String email) async {
    final accounts = await _getAccounts();
    return accounts.any((a) => a['email'] == email.toLowerCase());
  }

  /// Register a new account
  /// Returns null on success, error message on failure
  Future<String?> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();

    // Validate email format
    if (!_isValidEmail(normalizedEmail)) {
      return 'Invalid email format';
    }

    // Check password strength
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    // Check if email already exists
    if (await isEmailRegistered(normalizedEmail)) {
      return 'Email already registered';
    }

    // Create new account
    final accounts = await _getAccounts();
    accounts.add({
      'email': normalizedEmail,
      'passwordHash': _hashPassword(password),
      'name': name.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _saveAccounts(accounts);
    return null; // Success
  }

  /// Login with email and password
  /// Returns user data on success, null on failure
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();
    final accounts = await _getAccounts();

    final account = accounts.cast<Map<String, dynamic>?>().firstWhere(
      (a) => a!['email'] == normalizedEmail,
      orElse: () => null,
    );

    if (account == null) return null;

    // Verify password
    final passwordHash = _hashPassword(password);
    if (account['passwordHash'] != passwordHash) return null;

    // Save current user
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, normalizedEmail);

    return account;
  }

  /// Get currently logged in user
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final currentEmail = prefs.getString(_currentUserKey);
    if (currentEmail == null) return null;

    final accounts = await _getAccounts();
    return accounts.cast<Map<String, dynamic>?>().firstWhere(
      (a) => a!['email'] == currentEmail,
      orElse: () => null,
    );
  }

  /// Logout current user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  /// Update user name
  Future<void> updateUserName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final currentEmail = prefs.getString(_currentUserKey);
    if (currentEmail == null) return;

    final accounts = await _getAccounts();
    final index = accounts.indexWhere((a) => a['email'] == currentEmail);
    if (index != -1) {
      accounts[index]['name'] = newName.trim();
      await _saveAccounts(accounts);
    }
  }

  /// Generate a verification code for the given email
  /// In a real app, this would send an email. Here we just return a code.
  Future<String?> generateVerificationCode(String email) async {
    final normalizedEmail = email.toLowerCase().trim();
    if (!await isEmailRegistered(normalizedEmail)) {
      return null;
    }
    // Mock code generation (fixed for simplicity or random)
    return '123456';
  }

  /// Reset password for a given email
  Future<bool> resetPassword(String email, String newPassword) async {
    final normalizedEmail = email.toLowerCase().trim();
    final accounts = await _getAccounts();

    final index = accounts.indexWhere((a) => a['email'] == normalizedEmail);
    if (index == -1) return false;

    accounts[index]['passwordHash'] = _hashPassword(newPassword);
    await _saveAccounts(accounts);
    return true;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
