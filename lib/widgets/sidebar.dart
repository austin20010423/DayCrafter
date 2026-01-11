import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../styles.dart';

Color _parseHexColor(String? hex) {
  if (hex == null) return AppStyles.mTextSecondary;
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('0xFF$clean'));
  } catch (e) {
    return AppStyles.mTextSecondary;
  }
}

class Sidebar extends StatelessWidget {
  final VoidCallback? onAddProject;
  const Sidebar({super.key, this.onAddProject});

  void _showDeleteDialog(
    BuildContext context,
    DayCrafterProvider provider,
    String projectId,
    String projectName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete "$projectName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteProject(projectId);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final projects = provider.projects;
    final activeProjectId = provider.activeProjectId;

    return Container(
      width: 280,
      color: AppStyles.mSidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              children: [
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
                const Text(
                  'DayCrafter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Navigation Group based on sketch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _SidebarItem(
                  label: 'Search',
                  icon: LucideIcons.search,
                  isActive: false,
                  onTap: () {},
                ),
                _SidebarItem(
                  label: 'Dashboard',
                  icon: LucideIcons.barChart3,
                  isActive: false,
                  onTap: () {},
                ),
                _SidebarItem(
                  label: 'Agent',
                  icon: LucideIcons.smile,
                  isActive: provider.activeProjectId != null,
                  onTap: () {
                    if (provider.activeProjectId == null &&
                        provider.projects.isNotEmpty) {
                      provider.setActiveProject(provider.projects.first.id);
                    }
                  },
                ),
                _SidebarItem(
                  label: 'Schedule',
                  icon: LucideIcons.calendar,
                  isActive: false,
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Project Section Header based on sketch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                const Text(
                  'Project',
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
                  onPressed: onAddProject,
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

          const SizedBox(height: 16),

          // Project List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final isActive = project.id == activeProjectId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _ProjectItem(
                    label: project.name,
                    isActive: isActive,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppStyles.mSecondary,
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
                      Text(
                        'Personal Plan',
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
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppStyles.bRadiusMedium,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppStyles.mPrimary.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: AppStyles.bRadiusMedium,
        ),
        child: Row(
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
                  color: isActive ? Colors.white : AppStyles.mTextSecondary,
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
    );
  }
}

class _ProjectItem extends StatefulWidget {
  final String label;
  final bool isActive;
  final Color? markColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    this.markColor,
  });

  @override
  State<_ProjectItem> createState() => _ProjectItemState();
}

class _ProjectItemState extends State<_ProjectItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppStyles.bRadiusMedium,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppStyles.mPrimary.withValues(alpha: 0.3)
                : (_isHovered
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.transparent),
            borderRadius: AppStyles.bRadiusMedium,
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.folder,
                size: 20,
                color: widget.isActive
                    ? Colors.white
                    : AppStyles.mTextSecondary,
              ),
              const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
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
