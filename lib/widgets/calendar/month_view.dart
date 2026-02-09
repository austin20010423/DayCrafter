import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../provider.dart';
import '../../styles.dart';
import '../../l10n/app_localizations.dart';
import '../task_detail_dialog.dart';

/// Month View - Shows a full month calendar grid
class MonthView extends StatelessWidget {
  const MonthView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final selectedDate = provider.selectedDate;

    return Column(
      children: [
        // Header with month/year and navigation
        _buildHeader(context, provider, selectedDate),
        const SizedBox(height: 16),
        // Main content: Calendar grid on left, task lists on right
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Calendar grid takes most space
              Expanded(
                flex: 3,
                child: _buildCalendarGrid(context, provider, selectedDate),
              ),
              const SizedBox(width: 16),
              // Task lists on the right
              SizedBox(
                width: 200,
                child: _buildRightPanel(context, provider, selectedDate),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DayCrafterProvider provider,
    DateTime selectedDate,
  ) {
    final localeString = provider.locale == AppLocale.chinese
        ? 'zh_TW'
        : 'en_US';
    final monthYear = DateFormat(
      'MMMM yyyy',
      localeString,
    ).format(selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppStyles.mSurface,
        borderRadius: AppStyles.bRadiusMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return isNarrow
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthYear,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.mTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: provider.navigatePrevious,
                        icon: const Icon(LucideIcons.chevronLeft),
                        color: AppStyles.mTextSecondary,
                      ),
                      IconButton(
                        onPressed: provider.navigateNext,
                        icon: const Icon(LucideIcons.chevronRight),
                        color: AppStyles.mTextSecondary,
                      ),
                      const SizedBox(width: 24),
                      _buildViewToggleCompact(context, provider),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => provider.setCalendarActive(false),
                        icon: const Icon(LucideIcons.x),
                        color: AppStyles.mTextSecondary,
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Text(
                      monthYear,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.mTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: provider.navigatePrevious,
                      icon: const Icon(LucideIcons.chevronLeft),
                      color: AppStyles.mTextSecondary,
                    ),
                    IconButton(
                      onPressed: provider.navigateNext,
                      icon: const Icon(LucideIcons.chevronRight),
                      color: AppStyles.mTextSecondary,
                    ),
                    const Spacer(),
                    _buildViewToggleCompact(context, provider),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => provider.setCalendarActive(false),
                      icon: const Icon(LucideIcons.x),
                      color: AppStyles.mTextSecondary,
                    ),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    DayCrafterProvider provider,
    DateTime selectedDate,
  ) {
    // Get first day of month and calculate grid
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastDayOfMonth = DateTime(
      selectedDate.year,
      selectedDate.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;

    // Start from Sunday = 0
    final firstWeekday = firstDayOfMonth.weekday % 7;

    // Calculate total cells needed (including leading empty cells)
    final totalCells = firstWeekday + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    final today = DateTime.now();
    final dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.mSurface,
        borderRadius: AppStyles.bRadiusMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Day names header
            Row(
              children: dayNames.map((name) {
                return Expanded(
                  child: Center(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.mTextSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Calendar grid
            Expanded(
              child: Column(
                children: List.generate(totalRows, (rowIndex) {
                  return Expanded(
                    child: Row(
                      children: List.generate(7, (colIndex) {
                        final cellIndex = rowIndex * 7 + colIndex;
                        final dayNum = cellIndex - firstWeekday + 1;

                        // Empty cell or valid day
                        if (dayNum < 1 || dayNum > daysInMonth) {
                          return const Expanded(child: SizedBox());
                        }

                        final cellDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          dayNum,
                        );
                        final isToday =
                            cellDate.year == today.year &&
                            cellDate.month == today.month &&
                            cellDate.day == today.day;
                        final isSelected = cellDate.day == selectedDate.day;

                        return Expanded(
                          child: _DayCell(
                            date: cellDate,
                            isToday: isToday,
                            isSelected: isSelected,
                            dayNum: dayNum,
                            provider: provider,
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel(
    BuildContext context,
    DayCrafterProvider provider,
    DateTime selectedDate,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    return Column(
      children: [
        Expanded(
          child: _TaskListCard(title: l10n.today, date: today),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _TaskListCard(
            title: l10n.tomorrow,
            date: tomorrow,
            isHighlighted: true,
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggleCompact(
    BuildContext context,
    DayCrafterProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewToggleButton(
          label: l10n.day,
          isActive: provider.currentCalendarView == CalendarViewType.day,
          onTap: () => provider.setCalendarView(CalendarViewType.day),
          compact: true,
        ),
        const SizedBox(width: 4),
        _ViewToggleButton(
          label: l10n.week,
          isActive: provider.currentCalendarView == CalendarViewType.week,
          onTap: () => provider.setCalendarView(CalendarViewType.week),
          compact: true,
        ),
        const SizedBox(width: 4),
        _ViewToggleButton(
          label: l10n.month,
          isActive: provider.currentCalendarView == CalendarViewType.month,
          onTap: () => provider.setCalendarView(CalendarViewType.month),
          compact: true,
        ),
      ],
    );
  }
}

class _DayCell extends StatefulWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final int dayNum;
  final DayCrafterProvider provider;

  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.dayNum,
    required this.provider,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  final _link = LayerLink();
  bool _isHovered = false;
  OverlayEntry? _overlayEntry;

  void _showTooltip() {
    final tasks = widget.provider.getTasksForDate(widget.date);
    if (tasks.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 240,
        child: IgnorePointer(
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: const Offset(30, -10),
            child: Material(
              color: Colors.transparent,
              child: _TaskHoverTooltip(tasks: tasks, date: widget.date),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTooltip() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.opaque,
        onEnter: (_) {
          Future.microtask(() {
            if (mounted) {
              setState(() => _isHovered = true);
              _showTooltip();
            }
          });
        },
        onExit: (_) {
          Future.microtask(() {
            if (mounted) {
              setState(() => _isHovered = false);
              _hideTooltip();
            }
          });
        },
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.provider.setSelectedDate(widget.date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppStyles.mPrimary.withValues(alpha: 0.15)
                  : (_isHovered
                        ? AppStyles.mPrimary.withValues(alpha: 0.05)
                        : Colors.transparent),
              borderRadius: AppStyles.bRadiusSmall,
              border: widget.isToday
                  ? Border.all(color: AppStyles.mPrimary, width: 2)
                  : (_isHovered
                        ? Border.all(
                            color: AppStyles.mPrimary.withValues(alpha: 0.3),
                            width: 1,
                          )
                        : null),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppStyles.mPrimary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.dayNum.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: widget.isToday || widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: widget.isSelected
                            ? Colors.white
                            : (widget.isToday
                                  ? AppStyles.mPrimary
                                  : AppStyles.mTextPrimary),
                      ),
                    ),
                  ),
                ),
                _buildIndicators(),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicators() {
    final tasks = widget.provider.getTasksForDate(widget.date);
    if (tasks.isEmpty) return const SizedBox();

    final projectColors = <String>{};
    for (final task in tasks) {
      final priority = task['priority'] is int
          ? task['priority']
          : int.tryParse(task['priority']?.toString() ?? '3') ?? 3;

      String colorKey;
      final projectId = task['projectId']?.toString();

      if (projectId != null) {
        try {
          final project = widget.provider.projects.firstWhere(
            (p) => p.id == projectId,
            orElse: () => widget.provider.projects.first,
          );
          colorKey =
              project.colorHex ??
              AppStyles.getPriorityColor(priority).value.toRadixString(16);
        } catch (_) {
          colorKey = AppStyles.getPriorityColor(
            priority,
          ).value.toRadixString(16);
        }
      } else {
        colorKey = AppStyles.getPriorityColor(priority).value.toRadixString(16);
      }
      projectColors.add(colorKey);
    }

    final uniqueColors = projectColors.take(5).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: uniqueColors.map((hexStr) {
          Color color;
          try {
            final cleanHex = hexStr.replaceAll('#', '');
            if (cleanHex.length == 6) {
              color = Color(int.parse('FF$cleanHex', radix: 16));
            } else if (cleanHex.length == 8) {
              color = Color(int.parse(cleanHex, radix: 16));
            } else {
              color = AppStyles.mPrimary;
            }
          } catch (_) {
            color = AppStyles.mPrimary;
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          );
        }).toList(),
      ),
    );
  }
}

class _TaskHoverTooltip extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final DateTime date;

  const _TaskHoverTooltip({required this.tasks, required this.date});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy').format(date);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppStyles.mSurface.withValues(alpha: 0.95),
        borderRadius: AppStyles.bRadiusSmall,
        border: Border.all(color: AppStyles.mPrimary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppStyles.mPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: tasks.length > 5 ? 5 : tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                final priority = task['priority'] is int
                    ? task['priority']
                    : int.tryParse(task['priority']?.toString() ?? '3') ?? 3;
                final priorityColor = AppStyles.getPriorityColor(priority);
                final taskName = task['task']?.toString() ?? 'Untitled';
                final time = task['start_time']?.toString();

                return Row(
                  children: [
                    Container(
                      width: 4,
                      height: 14,
                      decoration: BoxDecoration(
                        color: priorityColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            taskName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.mTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (time != null && time.isNotEmpty)
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppStyles.mTextSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (tasks.length > 5) ...[
            const SizedBox(height: 8),
            Text(
              '+ ${tasks.length - 5} more tasks',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppStyles.mTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskListCard extends StatelessWidget {
  final String title;
  final DateTime date;
  final bool isHighlighted;

  const _TaskListCard({
    required this.title,
    required this.date,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final tasks = provider.getTasksForDate(date);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppStyles.mPrimary.withValues(alpha: 0.1)
            : AppStyles.mSurface,
        borderRadius: AppStyles.bRadiusSmall,
        border: isHighlighted
            ? Border.all(
                color: AppStyles.mPrimary.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.listTodo,
                size: 16,
                color: isHighlighted
                    ? AppStyles.mPrimary
                    : AppStyles.mTextSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title (${tasks.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isHighlighted
                        ? AppStyles.mPrimary
                        : AppStyles.mTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context)!.noTasks,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.mTextSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final priority = task['priority'] is int
                          ? task['priority']
                          : int.tryParse(task['priority']?.toString() ?? '3') ??
                                3;
                      final priorityColor = AppStyles.getPriorityColor(
                        priority,
                      );
                      final isCompleted = task['isCompleted'] == true;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => TaskDetailDialog.show(context, task),
                          borderRadius: AppStyles.bRadiusSmall,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.1),
                              borderRadius: AppStyles.bRadiusSmall,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCompleted
                                      ? LucideIcons.checkCircle
                                      : LucideIcons.circle,
                                  size: 12,
                                  color: isCompleted
                                      ? AppStyles.mAccent
                                      : priorityColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    task['task']?.toString() ?? 'Untitled',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppStyles.mTextPrimary,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool compact;

  const _ViewToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.bRadiusSmall,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 24,
            vertical: compact ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppStyles.mPrimary : AppStyles.mSurface,
            borderRadius: AppStyles.bRadiusSmall,
            border: Border.all(
              color: isActive
                  ? AppStyles.mPrimary
                  : AppStyles.mTextSecondary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppStyles.mTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
