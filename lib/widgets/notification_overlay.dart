import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../styles.dart';
import '../provider.dart';
import 'task_detail_dialog.dart';

class NotificationButton extends StatefulWidget {
  const NotificationButton({super.key});

  @override
  State<NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<NotificationButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _isHovered = false;

  // Track the number of tasks we've "seen" (opened the panel for)
  int _lastSeenCount = 0;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    // When opening, we "read" all current tasks
    final provider = context.read<DayCrafterProvider>();
    final today = DateTime.now();
    final tasks = provider.getTasksForDate(today);
    setState(() {
      _lastSeenCount = tasks.length;
      _isOpen = true;
    });

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent dismissible barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown content
          Positioned(
            width: 360,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-320 + 40, 50), // Align right edge roughly
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppStyles.mSurface.withValues(alpha: 0.95),
                    borderRadius: AppStyles.bRadiusMedium,
                    border: Border.all(color: AppStyles.mBackground, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppStyles.bRadiusMedium,
                    child: _NotificationList(onClose: _removeOverlay),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getTopTasks(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final today = DateTime.now();
    final tasks = provider.getTasksForDate(today);

    // Sort by priority (1=High, 2=Medium, 3=Low)
    tasks.sort((a, b) {
      final pA = a['priority'] is int ? a['priority'] as int : 3;
      final pB = b['priority'] is int ? b['priority'] as int : 3;
      return pA.compareTo(pB);
    });

    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = _getTopTasks(context);
    // Show badge if we have more tasks than we last saw
    // If the count drops (tasks deleted), _lastSeenCount might be higher,
    // so ensure we don't show negative badge (implied by > condition).
    // And if tasks > 0 and we haven't seen them.
    // However, simplest "unread" logic per user request:
    // "click open ... red dot will be dissapear"
    // So if current count > last seen count, show dot.
    final hasUnread = allTasks.isNotEmpty && allTasks.length > _lastSeenCount;
    final unreadCount = allTasks.length - _lastSeenCount;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: 'Notifications',
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: _toggleOverlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isHovered || _isOpen
                    ? AppStyles.mPrimary.withValues(alpha: 0.15)
                    : AppStyles.mBackground.withValues(alpha: 0.5),
                borderRadius: AppStyles.bRadiusSmall,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    LucideIcons.bell,
                    size: 20,
                    color: _isHovered || _isOpen
                        ? AppStyles.mPrimary
                        : AppStyles.mTextPrimary,
                  ),
                  if (hasUnread)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppStyles.mSurface,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            // Show total count or just unread?
                            // Usually a dot shows "something new".
                            // If I have 5 tasks and saw 4, seeing "1" is correct.
                            // But usually bell badges show TOTAL unread.
                            // If I cleared it, then 0.
                            // If a new one comes in, show 1? Or 6?
                            // User asked: "click open all the notification then the red dot will be dissapear"
                            // So we just hide the dot. We don't need a number inside necessarily,
                            // but if we do, it should probably be the number of "new" things.
                            // Let's just show the dot or the count of new items.
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 6,
                              fontWeight: FontWeight.bold,
                            ),
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
}

class _NotificationList extends StatelessWidget {
  final VoidCallback onClose;

  const _NotificationList({required this.onClose});

  @override
  Widget build(BuildContext context) {
    // Re-fetch tasks here to ensure the list is up-to-date when built
    // We could pass them in, but this is clean enough for now.
    final provider = context.watch<DayCrafterProvider>();
    final today = DateTime.now();
    final tasks = provider.getTasksForDate(today);

    tasks.sort((a, b) {
      final pA = a['priority'] is int ? a['priority'] as int : 3;
      final pB = b['priority'] is int ? b['priority'] as int : 3;
      return pA.compareTo(pB);
    });

    final topTasks = tasks.take(2).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.mTextPrimary,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppStyles.mBackground),
        // List
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: topTasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No important tasks for today',
                      style: TextStyle(
                        color: AppStyles.mTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: topTasks.length,
                  itemBuilder: (context, index) {
                    final task = topTasks[index];
                    return _NotificationItem(
                      item: task,
                      rank: index + 1,
                      onTap: () {
                        // Navigate to date
                        final dateStr = task['dateOnCalendar']?.toString();
                        if (dateStr != null) {
                          final date = DateTime.tryParse(dateStr);
                          if (date != null) {
                            provider.setActiveNavItem(NavItem.calendar);
                            provider.setSelectedDate(date);
                          }
                        }
                        // Close overlay first
                        onClose();
                        // Then show details
                        // We use a slight delay to allow overlay to close smoothly
                        // and scene to update? No, dialog pushes on top.
                        // But we want to see the calendar first?
                        // Actually, showDialog pushes a route.
                        // If we swap the order, we might get the dialog on top of the notification overlay
                        // if we didn't close it yet.
                        // onClose removes the overlay entry.
                        // So calling onClose() then TaskDetailDialog.show() is correct.
                        TaskDetailDialog.show(context, task);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final int rank;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.item,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Map priority to color
    final priority = item['priority'] is int ? item['priority'] as int : 3;
    final priorityColor = AppStyles.getPriorityColor(priority);

    // Title
    final title = item['task'] ?? 'Untitled Task';
    // Description or time range
    final description =
        item['Description']?.toString() ??
        (item['start_time'] != null
            ? '${item['start_time']} - ${item['end_time']}'
            : 'No description');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank/Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: priorityColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: priorityColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.mTextPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppStyles.mTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Priority Dot
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priorityColor,
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
