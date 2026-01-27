import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../styles.dart';
import '../l10n/app_localizations.dart';

Color _parseHexColor(String? hex) {
  if (hex == null) return AppStyles.mTextSecondary;
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('0xFF$clean'));
  } catch (e) {
    return AppStyles.mTextSecondary;
  }
}

class Sidebar extends StatefulWidget {
  final VoidCallback? onAddProject;
  const Sidebar({super.key, this.onAddProject});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;

  static const double _expandedWidth = 280.0;
  static const double _collapsedWidth = 72.0;
  static const Duration _animationDuration = Duration(milliseconds: 200);

  void _showDeleteDialog(
    BuildContext context,
    DayCrafterProvider provider,
    String projectId,
    String projectName,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProject),
        content: Text(l10n.deleteProjectConfirm(projectName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              provider.deleteProject(projectId);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final l10n = AppLocalizations.of(context)!;
    final projects = provider.projects;
    final activeProjectId = provider.activeProjectId;

    return AnimatedContainer(
      duration: _animationDuration,
      curve: Curves.easeInOut,
      width: _isCollapsed ? _collapsedWidth : _expandedWidth,
      color: AppStyles.mSidebarBg,
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use actual width to determine layout, not just _isCollapsed state
          final showExpanded = constraints.maxWidth > 150;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo Section with collapse toggle
              if (!showExpanded)
                // Collapsed header - centered menu button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: InkWell(
                      onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                      borderRadius: AppStyles.bRadiusSmall,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: AppStyles.bRadiusSmall,
                        ),
                        child: const Icon(
                          LucideIcons.menu,
                          size: 20,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                )
              else
                // Expanded header - full row
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      // Menu/Collapse toggle button
                      InkWell(
                        onTap: () =>
                            setState(() => _isCollapsed = !_isCollapsed),
                        borderRadius: AppStyles.bRadiusSmall,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: AppStyles.bRadiusSmall,
                          ),
                          child: const Icon(
                            LucideIcons.panelLeftClose,
                            size: 20,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Logo
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppStyles.mPrimary,
                          borderRadius: AppStyles.bRadiusSmall,
                        ),
                        child: const Icon(
                          LucideIcons.zap,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.appTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // Collapsed: Show logo centered below menu button
              if (!showExpanded)
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppStyles.mPrimary,
                      borderRadius: AppStyles.bRadiusSmall,
                    ),
                    child: const Icon(
                      LucideIcons.zap,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),

              if (!showExpanded) const SizedBox(height: 24),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: showExpanded ? 16 : 12,
                ),
                child: Column(
                  children: [
                    _SidebarItem(
                      label: l10n.calendar,
                      icon: LucideIcons.calendar,
                      isActive: provider.activeNavItem == NavItem.calendar,
                      isCollapsed: !showExpanded,
                      onTap: () => provider.setActiveNavItem(NavItem.calendar),
                    ),
                    _SidebarItem(
                      label: l10n.agent,
                      icon: LucideIcons.smile,
                      isActive: provider.activeNavItem == NavItem.agent,
                      isCollapsed: !showExpanded,
                      onTap: () {
                        provider.setActiveNavItem(NavItem.agent);
                        if (provider.activeProjectId == null &&
                            provider.projects.isNotEmpty) {
                          provider.setActiveProject(provider.projects.first.id);
                        }
                      },
                    ),
                    _SidebarItem(
                      label: l10n.dashboard,
                      icon: LucideIcons.barChart3,
                      isActive: provider.activeNavItem == NavItem.dashboard,
                      isCollapsed: !showExpanded,
                      onTap: () => provider.setActiveNavItem(NavItem.dashboard),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Project Section Header - hide when collapsed
              if (showExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Text(
                        l10n.project,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        LucideIcons.chevronDown,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: widget.onAddProject,
                        icon: const Icon(
                          LucideIcons.plusCircle,
                          size: 20,
                          color: Colors.white70,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

              // Collapsed: Show add project button centered
              if (!showExpanded)
                Center(
                  child: IconButton(
                    onPressed: widget.onAddProject,
                    icon: const Icon(
                      LucideIcons.plusCircle,
                      size: 24,
                      color: Colors.white70,
                    ),
                    tooltip: 'Add Project',
                  ),
                ),

              if (showExpanded) const SizedBox(height: 16),

              // Project List
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: showExpanded ? 16 : 12,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final isActive = project.id == activeProjectId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _ProjectItem(
                        label: project.name,
                        emoji: project.emoji,
                        isActive: isActive,
                        isCollapsed: !showExpanded,
                        markColor: _parseHexColor(project.colorHex),
                        onTap: () => provider.setActiveProject(project.id),
                        onDelete: () => _showDeleteDialog(
                          context,
                          provider,
                          project.id,
                          project.name,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // User Section
              Container(
                padding: EdgeInsets.all(showExpanded ? 24 : 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                  ),
                ),
                child: !showExpanded
                    ? Center(
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppStyles.mSecondary,
                          child: Text(
                            provider.userName?.isNotEmpty == true
                                ? provider.userName![0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppStyles.mSecondary,
                            child: Text(
                              provider.userName?.isNotEmpty == true
                                  ? provider.userName![0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.userName ?? 'User',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  l10n.personalPlan,
                                  style: TextStyle(
                                    color: AppStyles.mTextSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            LucideIcons.moreVertical,
                            size: 18,
                            color: Colors.white54,
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isCollapsed ? label : '',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.bRadiusMedium,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 12 : 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppStyles.mPrimary.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: AppStyles.bRadiusMedium,
          ),
          child: isCollapsed
              ? Center(
                  child: Icon(
                    icon,
                    size: 22,
                    color: isActive ? Colors.white : AppStyles.mTextSecondary,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isActive ? Colors.white : AppStyles.mTextSecondary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : AppStyles.mTextSecondary,
                          fontSize: 15,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isActive)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ProjectItem extends StatefulWidget {
  final String label;
  final String? emoji;
  final bool isActive;
  final bool isCollapsed;
  final Color? markColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    this.emoji,
    this.isCollapsed = false,
    this.markColor,
  });

  @override
  State<_ProjectItem> createState() => _ProjectItemState();
}

class _ProjectItemState extends State<_ProjectItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Collapsed view - show emoji or folder icon with color indicator
    if (widget.isCollapsed) {
      return Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 500),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppStyles.bRadiusMedium,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              // Use project color in collapsed view too
              color: widget.isActive
                  ? (widget.markColor ?? AppStyles.mPrimary).withValues(
                      alpha: 0.35,
                    )
                  : (widget.markColor ?? Colors.transparent).withValues(
                      alpha: 0.1,
                    ),
              borderRadius: AppStyles.bRadiusMedium,
            ),
            child: Center(
              child: widget.emoji != null && widget.emoji!.isNotEmpty
                  ? Text(widget.emoji!, style: TextStyle(fontSize: 22))
                  : Stack(
                      children: [
                        Icon(
                          LucideIcons.folder,
                          size: 22,
                          color: widget.isActive
                              ? Colors.white
                              : AppStyles.mTextSecondary,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  widget.markColor ?? AppStyles.mTextSecondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppStyles.mSidebarBg,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    // Expanded view - show color-tinted background
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppStyles.bRadiusMedium,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // Use project color as subtle background tint
            color: widget.isActive
                ? (widget.markColor ?? AppStyles.mPrimary).withValues(
                    alpha: 0.35,
                  )
                : (_isHovered
                      ? (widget.markColor ?? Colors.white).withValues(
                          alpha: 0.15,
                        )
                      : (widget.markColor ?? Colors.transparent).withValues(
                          alpha: 0.08,
                        )),
            borderRadius: AppStyles.bRadiusMedium,
            // Add subtle border with project color
            border: widget.isActive
                ? Border.all(
                    color: (widget.markColor ?? AppStyles.mPrimary).withValues(
                      alpha: 0.5,
                    ),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Show emoji or folder icon
              widget.emoji != null && widget.emoji!.isNotEmpty
                  ? Text(widget.emoji!, style: TextStyle(fontSize: 20))
                  : Icon(
                      LucideIcons.folder,
                      size: 20,
                      color: widget.isActive
                          ? Colors.white
                          : AppStyles.mTextSecondary,
                    ),
              const SizedBox(width: 12),
              // Color dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? Colors.white
                      : (widget.markColor ?? AppStyles.mTextSecondary),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isActive
                        ? Colors.white
                        : AppStyles.mTextSecondary,
                    fontSize: 15,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Delete button - visible on hover or when active
              if (_isHovered || widget.isActive)
                IconButton(
                  onPressed: widget.onDelete,
                  icon: Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: _isHovered ? Colors.red.shade300 : Colors.white54,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  splashRadius: 16,
                  tooltip: 'Delete project',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
