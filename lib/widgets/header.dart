import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../styles.dart';

class Header extends StatelessWidget {
  final String? activeProjectName;

  const Header({super.key, this.activeProjectName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: AppStyles.mSurface,
        border: Border(
          bottom: BorderSide(color: AppStyles.mBackground, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: AppStyles.mTextSecondary,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w300,
              ),
              children: [
                const TextSpan(text: 'Workspaces / '),
                TextSpan(
                  text: activeProjectName ?? 'Default',
                  style: TextStyle(
                    color: AppStyles.mTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _HeaderIconButton(icon: LucideIcons.search),
              const SizedBox(width: 20),
              _HeaderIconButton(icon: LucideIcons.bell),
              const SizedBox(width: 20),
              _HeaderIconButton(icon: LucideIcons.settings),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  const _HeaderIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.mBackground.withValues(alpha: 0.5),
        borderRadius: AppStyles.bRadiusSmall,
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, size: 20, color: AppStyles.mTextPrimary),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
    );
  }
}
