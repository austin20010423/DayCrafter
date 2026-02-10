import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../styles.dart';

/// Login screen for existing users
class LoginScreen extends StatefulWidget {
  final VoidCallback onSwitchToRegister;
  final VoidCallback? onForgotPassword;
  final Future<bool> Function(String email, String password) onLogin;
  final Future<List<Map<String, String>>> Function()? onGetAccounts;
  final Future<void> Function(String email)? onDeleteAccount;

  const LoginScreen({
    super.key,
    required this.onSwitchToRegister,
    this.onForgotPassword,
    required this.onLogin,
    this.onGetAccounts,
    this.onDeleteAccount,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  List<Map<String, String>> _registeredAccounts = [];
  String? _selectedAccountEmail;

  @override
  void initState() {
    super.initState();
    _loadRegisteredAccounts();
  }

  Future<void> _loadRegisteredAccounts() async {
    if (widget.onGetAccounts != null) {
      final accounts = await widget.onGetAccounts!();
      if (mounted) {
        setState(() {
          _registeredAccounts = accounts;
        });
      }
    }
  }

  void _selectAccount(Map<String, String> account) {
    setState(() {
      _selectedAccountEmail = account['email'];
      _emailController.text = account['email'] ?? '';
      _passwordController.clear();
      _errorMessage = null;
    });
    // Focus on password field after selecting account
    Future.delayed(const Duration(milliseconds: 100), () {
      _passwordFocusNode.requestFocus();
    });
  }

  void _clearSelectedAccount() {
    setState(() {
      _selectedAccountEmail = null;
      _emailController.clear();
      _passwordController.clear();
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await widget.onLogin(
      _emailController.text,
      _passwordController.text,
    );

    if (!success && mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid email or password';
      });
    }
  }

  String _getInitials(String name, String email) {
    if (name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  Widget _buildAccountSelector() {
    if (_registeredAccounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose an account',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppStyles.mTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _registeredAccounts.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              // Last item is "Use another account" button
              if (index == _registeredAccounts.length) {
                return _buildAddAccountCard();
              }

              final account = _registeredAccounts[index];
              final isSelected = _selectedAccountEmail == account['email'];
              return _buildAccountCard(account, isSelected);
            },
          ),
        ),
        const SizedBox(height: 24),
        if (_selectedAccountEmail != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppStyles.mPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.user, size: 16, color: AppStyles.mPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Signing in as $_selectedAccountEmail',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppStyles.mPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _clearSelectedAccount,
                  child: Icon(
                    LucideIcons.x,
                    size: 16,
                    color: AppStyles.mPrimary,
                  ),
                ),
              ],
            ),
          ),
        if (_selectedAccountEmail != null) const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _handleDeleteAccount(Map<String, String> account) async {
    final email = account['email'];
    if (email == null || widget.onDeleteAccount == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Are you sure you want to remove $email from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.onDeleteAccount!(email);
      await _loadRegisteredAccounts();
      if (_selectedAccountEmail == email) {
        _clearSelectedAccount();
      }
    }
  }

  Widget _buildAccountCard(Map<String, String> account, bool isSelected) {
    final name = account['name'] ?? '';
    final email = account['email'] ?? '';
    final initials = _getInitials(name, email);

    return Stack(
      children: [
        GestureDetector(
          onTap: () => _selectAccount(account),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 140,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppStyles.mPrimary.withValues(alpha: 0.1)
                  : AppStyles.mBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppStyles.mPrimary
                    : AppStyles.mTextSecondary.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppStyles.mPrimary
                        : AppStyles.mPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppStyles.mPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name.isNotEmpty ? name : email.split('@')[0],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.mTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppStyles.mTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        if (isSelected)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _handleDeleteAccount(account),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.trash2,
                  size: 14,
                  color: Colors.red,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddAccountCard() {
    return GestureDetector(
      onTap: _clearSelectedAccount,
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppStyles.mBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppStyles.mTextSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppStyles.mTextSecondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.plus,
                size: 18,
                color: AppStyles.mTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Other',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppStyles.mTextSecondary,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.mBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64, // 32 padding * 2
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppStyles.mSurface,
                    borderRadius: AppStyles.bRadiusMedium,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'DayCrafter',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.mTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your account',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppStyles.mTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Account selector
                        _buildAccountSelector(),

                        // Error message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.alertCircle,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email field (hidden when account is selected)
                        if (_selectedAccountEmail == null) ...[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _passwordFocusNode.requestFocus(),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(
                                LucideIcons.mail,
                                color: AppStyles.mPrimary,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(
                              LucideIcons.lock,
                              color: AppStyles.mPrimary,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? LucideIcons.eyeOff
                                    : LucideIcons.eye,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Forgot Password Link
                        if (widget.onForgotPassword != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: widget.onForgotPassword,
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppStyles.mPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStyles.mPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(color: AppStyles.mTextSecondary),
                            ),
                            TextButton(
                              onPressed: widget.onSwitchToRegister,
                              child: Text(
                                'Create one',
                                style: TextStyle(color: AppStyles.mPrimary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
