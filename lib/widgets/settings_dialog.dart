import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../styles.dart';

/// Settings dialog with theme and language options
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();

    return Center(
      child: Container(
        width: 400,
        margin: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: AppStyles.mSurface,
          borderRadius: AppStyles.bRadiusMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppStyles.bRadiusMedium,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Theme Section
                      _buildSectionTitle('Appearance / 外觀'),
                      const SizedBox(height: 12),
                      _buildThemeSelector(provider),
                      const SizedBox(height: 24),

                      // Language Section
                      _buildSectionTitle('Language / 語言'),
                      const SizedBox(height: 12),
                      _buildLanguageSelector(provider),
                    ],
                  ),
                ),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppStyles.mPrimary.withValues(alpha: 0.1),
            AppStyles.mSecondary.withValues(alpha: 0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppStyles.mPrimary.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppStyles.mPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LucideIcons.settings,
              color: AppStyles.mPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Settings / 設定',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppStyles.mTextPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x, size: 20),
            color: AppStyles.mTextSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppStyles.mTextSecondary,
      ),
    );
  }

  Widget _buildThemeSelector(DayCrafterProvider provider) {
    return Row(
      children: [
        _ThemeOption(
          icon: LucideIcons.sun,
          label: 'Light',
          labelZh: '淺色',
          isSelected: provider.themeMode == AppThemeMode.light,
          onTap: () => provider.setThemeMode(AppThemeMode.light),
        ),
        const SizedBox(width: 12),
        _ThemeOption(
          icon: LucideIcons.moon,
          label: 'Dark',
          labelZh: '深色',
          isSelected: provider.themeMode == AppThemeMode.dark,
          onTap: () => provider.setThemeMode(AppThemeMode.dark),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(DayCrafterProvider provider) {
    return Row(
      children: [
        _LanguageOption(
          flag: '🇺🇸',
          label: 'English',
          isSelected: provider.locale == AppLocale.english,
          onTap: () => provider.setLocale(AppLocale.english),
        ),
        const SizedBox(width: 12),
        _LanguageOption(
          flag: '🇹🇼',
          label: '中文',
          isSelected: provider.locale == AppLocale.chinese,
          onTap: () => provider.setLocale(AppLocale.chinese),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppStyles.mBackground)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.mPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Done / 完成'),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String labelZh;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.labelZh,
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppStyles.mPrimary.withValues(alpha: 0.15)
                : AppStyles.mBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppStyles.mPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? AppStyles.mPrimary
                    : AppStyles.mTextSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppStyles.mPrimary
                      : AppStyles.mTextPrimary,
                ),
              ),
              Text(
                labelZh,
                style: TextStyle(fontSize: 12, color: AppStyles.mTextSecondary),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppStyles.mPrimary.withValues(alpha: 0.15)
                : AppStyles.mBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppStyles.mPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
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
