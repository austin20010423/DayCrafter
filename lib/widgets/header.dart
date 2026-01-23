import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../styles.dart';
import 'search_overlay.dart';
import 'settings_dialog.dart';

class Header extends StatelessWidget {
  final String? activeProjectName;

  const Header({super.key, this.activeProjectName});

  void _openSearch(BuildContext context) {
    SearchOverlay.show(context);
  }

  void _openSettings(BuildContext context) {
    SettingsDialog.show(context);
  }

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
              _HeaderIconButton(
                icon: LucideIcons.search,
                onPressed: () => _openSearch(context),
                tooltip: 'Search (⌘K)',
              ),
              const SizedBox(width: 20),
              _HeaderIconButton(
                icon: LucideIcons.settings,
                onPressed: () => _openSettings(context),
                tooltip: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppStyles.mPrimary.withValues(alpha: 0.15)
                : AppStyles.mBackground.withValues(alpha: 0.5),
            borderRadius: AppStyles.bRadiusSmall,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppStyles.mPrimary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: IconButton(
            onPressed: widget.onPressed,
            icon: Icon(
              widget.icon,
              size: 20,
              color: _isHovered ? AppStyles.mPrimary : AppStyles.mTextPrimary,
            ),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ),
      ),
    );
  }
}
