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
  bool _isProjectsExpanded = true;
  late AnimationController _projectsAnimationController;
  late Animation<double> _projectsExpansionAnimation;

  @override
  void initState() {
    super.initState();
    _projectsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _projectsExpansionAnimation = CurvedAnimation(
      parent: _projectsAnimationController,
      curve: Curves.easeInOutCubic,
    );
    _projectsAnimationController.value = 1.0; // Start expanded
  }

  @override
  void dispose() {
    _projectsAnimationController.dispose();
    super.dispose();
  }

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
                    child: _SidebarHoverButton(
                      onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                      child: const Icon(
                        LucideIcons.menu,
                        size: 20,
                        color: Colors.white70,
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
                      _SidebarHoverButton(
                        onTap: () =>
                            setState(() => _isCollapsed = !_isCollapsed),
                        child: Icon(
                          _isCollapsed
                              ? LucideIcons.panelLeftOpen
                              : LucideIcons.panelLeftClose,
                          size: 20,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Logo
                      ClipRRect(
                        borderRadius: AppStyles.bRadiusSmall,
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
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

              if (!showExpanded)
                Center(
                  child: ClipRRect(
                    borderRadius: AppStyles.bRadiusSmall,
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
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
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 4),
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

              // Project Section Area
              Expanded(
                child: showExpanded
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            // Project Section Header
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isProjectsExpanded = !_isProjectsExpanded;
                                    if (_isProjectsExpanded) {
                                      _projectsAnimationController.forward();
                                    } else {
                                      _projectsAnimationController.reverse();
                                    }
                                  });
                                },
                                borderRadius: AppStyles.bRadiusMedium,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 8.0,
                                  ),
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
                                      AnimatedRotation(
                                        turns: _isProjectsExpanded ? 0 : -0.25,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: const Icon(
                                          LucideIcons.chevronDown,
                                          size: 16,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const Spacer(),
                                      _SidebarHoverButton(
                                        onTap: widget.onAddProject,
                                        tooltip: 'Add Project',
                                        child: const Icon(
                                          LucideIcons.plusCircle,
                                          size: 20,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Project List with Animation
                            FadeTransition(
                              opacity: _projectsExpansionAnimation,
                              child: SizeTransition(
                                sizeFactor: _projectsExpansionAnimation,
                                axisAlignment: -1.0,
                                child: Column(
                                  children: [
                                    ...projects.map((project) {
                                      final isActive =
                                          project.id == activeProjectId;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                          left: 16,
                                          right: 16,
                                        ),
                                        child: _ProjectItem(
                                          label: project.name,
                                          icon: project.icon,
                                          isActive: isActive,
                                          isCollapsed: false,
                                          markColor: _parseHexColor(
                                            project.colorHex,
                                          ),
                                          onTap: () => provider
                                              .setActiveProject(project.id),
                                          onDelete: () => _showDeleteDialog(
                                            context,
                                            provider,
                                            project.id,
                                            project.name,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Collapsed: Show add project button centered
                          Center(
                            child: _SidebarHoverButton(
                              onTap: widget.onAddProject,
                              tooltip: 'Add Project',
                              child: const Icon(
                                LucideIcons.plusCircle,
                                size: 24,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Collapsed: Show project icons in a scrollable list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: projects.length,
                              itemBuilder: (context, index) {
                                final project = projects[index];
                                final isActive = project.id == activeProjectId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: _ProjectItem(
                                    label: project.name,
                                    icon: project.icon,
                                    isActive: isActive,
                                    isCollapsed: true,
                                    markColor: _parseHexColor(project.colorHex),
                                    onTap: () =>
                                        provider.setActiveProject(project.id),
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
                        ],
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
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppStyles.mSecondary,
                            borderRadius: AppStyles.bRadiusSmall,
                          ),
                          child: Center(
                            child: Text(
                              provider.userName?.isNotEmpty == true
                                  ? provider.userName![0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppStyles.mSecondary,
                              borderRadius: AppStyles.bRadiusSmall,
                            ),
                            child: Center(
                              child: Text(
                                provider.userName?.isNotEmpty == true
                                    ? provider.userName![0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
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

class _SidebarItem extends StatefulWidget {
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
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget item = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppStyles.bRadiusSmall,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 12 : 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppStyles.mPrimary.withValues(alpha: 0.3)
                : (_isHovered
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.transparent),
            borderRadius: AppStyles.bRadiusSmall,
          ),
          child: widget.isCollapsed
              ? Center(
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: widget.isActive
                        ? Colors.white
                        : (_isHovered
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppStyles.mTextSecondary),
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 20,
                      color: widget.isActive
                          ? Colors.white
                          : (_isHovered
                                ? Colors.white.withValues(alpha: 0.9)
                                : AppStyles.mTextSecondary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.isActive
                              ? Colors.white
                              : (_isHovered
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : AppStyles.mTextSecondary),
                          fontSize: 15,
                          fontWeight: widget.isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (widget.isActive)
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

    if (widget.isCollapsed) {
      return Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 500),
        child: item,
      );
    }

    return item;
  }
}

class _ProjectItem extends StatefulWidget {
  final String label;
  final String? icon;
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
    this.icon,
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
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppStyles.bRadiusMedium,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                // Use project color in collapsed view too
                color: widget.isActive
                    ? (widget.markColor ?? AppStyles.mPrimary).withValues(
                        alpha: 0.35,
                      )
                    : (_isHovered
                          ? (widget.markColor ?? AppStyles.mPrimary).withValues(
                              alpha: 0.2,
                            )
                          : (widget.markColor ?? Colors.transparent).withValues(
                              alpha: 0.1,
                            )),
                borderRadius: AppStyles.bRadiusMedium,
                border: Border.all(
                  color: _isHovered || widget.isActive
                      ? (widget.markColor ?? AppStyles.mPrimary).withValues(
                          alpha: 0.5,
                        )
                      : Colors.transparent,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _isHovered ? 0.25 : 0.15,
                    ),
                    blurRadius: _isHovered ? 12 : 8,
                    offset: Offset(0, _isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: Center(
                child: Stack(
                  children: [
                    Icon(
                      ProjectIcons.getIcon(widget.icon),
                      size: 22,
                      color: widget.isActive
                          ? Colors.white
                          : (widget.markColor ?? AppStyles.mTextSecondary),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.markColor ?? AppStyles.mTextSecondary,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // Use transparent/light background
            color: widget.isActive
                ? Colors.white.withValues(alpha: 0.1)
                : (_isHovered
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.transparent),
            borderRadius: AppStyles.bRadiusMedium,
            // Full border with project color
            border: Border.all(
              color: (widget.markColor ?? AppStyles.mPrimary).withValues(
                alpha: widget.isActive ? 1.0 : (_isHovered ? 0.8 : 0.4),
              ),
              width: widget.isActive ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.25 : 0.15),
                blurRadius: _isHovered ? 12 : 8,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Show icon
              Icon(
                ProjectIcons.getIcon(widget.icon),
                size: 20,
                color: widget.isActive
                    ? Colors.white
                    : (widget.markColor ?? AppStyles.mTextSecondary),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isActive
                        ? Colors.white
                        : (widget.markColor?.withValues(alpha: 0.7) ??
                              AppStyles.mTextSecondary),
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

class _SidebarHoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  const _SidebarHoverButton({required this.child, this.onTap, this.tooltip});

  @override
  State<_SidebarHoverButton> createState() => _SidebarHoverButtonState();
}

class _SidebarHoverButtonState extends State<_SidebarHoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onTap != null;

    Widget button = MouseRegion(
      onEnter: (_) => isEnabled ? setState(() => _isHovered = true) : null,
      onExit: (_) => isEnabled ? setState(() => _isHovered = false) : null,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppStyles.bRadiusSmall,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEnabled
                ? (_isHovered
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: AppStyles.bRadiusSmall,
            border: Border.all(
              color: isEnabled && _isHovered
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: widget.child,
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}
