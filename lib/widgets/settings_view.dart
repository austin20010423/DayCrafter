import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../styles.dart';
import '../l10n/app_localizations.dart';

/// Full-page settings view with theme and language options
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: AppStyles.mSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, l10n),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account Section
                      _buildSectionCard(
                        title: l10n.account,
                        icon: LucideIcons.user,
                        child: _buildAccountSection(context, provider, l10n),
                      ),
                      const SizedBox(height: 24),

                      // Appearance Section
                      _buildSectionCard(
                        title: l10n.appearance,
                        icon: LucideIcons.palette,
                        child: _buildThemeSelector(provider, l10n),
                      ),
                      const SizedBox(height: 24),

                      // Language Section
                      _buildSectionCard(
                        title: l10n.language,
                        icon: LucideIcons.globe,
                        child: _buildLanguageSelector(provider, l10n),
                      ),
                      const SizedBox(height: 24),

                      // About Section
                      _buildSectionCard(
                        title: l10n.about,
                        icon: LucideIcons.info,
                        child: _buildAboutSection(l10n),
                      ),
                      const SizedBox(height: 32),

                      // Logout Button at bottom
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              _showLogoutConfirmation(context, provider, l10n),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(l10n.logout),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    DayCrafterProvider provider,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppStyles.mPrimary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              (provider.userName ?? 'U').substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppStyles.mPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.userName ?? 'User',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.mTextPrimary,
                ),
              ),
              Text(
                provider.currentUserEmail ?? '',
                style: TextStyle(fontSize: 13, color: AppStyles.mTextSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(
    BuildContext context,
    DayCrafterProvider provider,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.logout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppStyles.mPrimary.withValues(alpha: 0.1),
            AppStyles.mSecondary.withValues(alpha: 0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppStyles.mBackground, width: 2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppStyles.mPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.settings,
              color: AppStyles.mPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            l10n.settings,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppStyles.mTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.mBackground.withValues(alpha: 0.5),
        borderRadius: AppStyles.bRadiusMedium,
        border: Border.all(color: AppStyles.mPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppStyles.mPrimary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.mTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppStyles.mPrimary.withValues(alpha: 0.1)),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(
    DayCrafterProvider provider,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        _ThemeOption(
          icon: LucideIcons.sun,
          label: l10n.lightMode,
          isSelected: provider.themeMode == AppThemeMode.light,
          onTap: () => provider.setThemeMode(AppThemeMode.light),
        ),
        const SizedBox(width: 16),
        _ThemeOption(
          icon: LucideIcons.moon,
          label: l10n.darkMode,
          isSelected: provider.themeMode == AppThemeMode.dark,
          onTap: () => provider.setThemeMode(AppThemeMode.dark),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(
    DayCrafterProvider provider,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        _LanguageOption(
          flag: '🇺🇸',
          label: l10n.english,
          isSelected: provider.locale == AppLocale.english,
          onTap: () => provider.setLocale(AppLocale.english),
        ),
        const SizedBox(width: 16),
        _LanguageOption(
          flag: '🇹🇼',
          label: l10n.chinese,
          isSelected: provider.locale == AppLocale.chinese,
          onTap: () => provider.setLocale(AppLocale.chinese),
        ),
      ],
    );
  }

  Widget _buildAboutSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.mTextPrimary,
                  ),
                ),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppStyles.mTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Your AI-powered project manager that helps you plan, organize, and track your tasks efficiently.',
          style: TextStyle(
            fontSize: 14,
            color: AppStyles.mTextSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? AppStyles.mPrimary.withValues(alpha: 0.15)
                : AppStyles.mSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppStyles.mPrimary : AppStyles.mBackground,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected
                    ? AppStyles.mPrimary
                    : AppStyles.mTextSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppStyles.mPrimary
                      : AppStyles.mTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? AppStyles.mPrimary.withValues(alpha: 0.15)
                : AppStyles.mSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppStyles.mPrimary : AppStyles.mBackground,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppStyles.mPrimary
                      : AppStyles.mTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
