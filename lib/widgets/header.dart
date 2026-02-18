import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../styles.dart';
import '../l10n/app_localizations.dart';
import 'search_overlay.dart';
import 'notification_overlay.dart';

class Header extends StatelessWidget {
  final String? locationName;
  final IconData? locationIcon;
  final Color? accentColor;

  const Header({
    super.key,
    this.locationName,
    this.locationIcon,
    this.accentColor,
  });

  void _openSearch(BuildContext context) {
    SearchOverlay.show(context);
  }

  void _openSettings(BuildContext context) {
    context.read<DayCrafterProvider>().closeAllOverlays();
    context.read<DayCrafterProvider>().setActiveNavItem(NavItem.settings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
          Row(
            children: [
              Text(
                'DayCrafter',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppStyles.mTextSecondary.withValues(alpha: 0.6),
                ),
              ),
              if (locationName != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppStyles.mTextSecondary.withValues(alpha: 0.3),
                  ),
                ),
                if (locationIcon != null) ...[
                  Icon(
                    locationIcon,
                    size: 18,
                    color: accentColor ?? AppStyles.mPrimary,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  locationName!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.mTextPrimary,
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              _HeaderIconButton(
                icon: LucideIcons.search,
                onPressed: () => _openSearch(context),
                tooltip: l10n.searchShortcut,
              ),
              const SizedBox(width: 12),
              const NotificationButton(),
              const SizedBox(width: 12),
              _HeaderIconButton(
                icon: LucideIcons.settings,
                onPressed: () => _openSettings(context),
                tooltip: l10n.settings,
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
