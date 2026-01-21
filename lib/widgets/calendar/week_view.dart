import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../provider.dart';
import '../../styles.dart';

/// Week View - Shows 7-day columns with hourly time slots
class WeekView extends StatelessWidget {
  const WeekView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final selectedDate = provider.selectedDate;

    // Get the week's start (Sunday) and end (Saturday)
    final weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday % 7),
    );
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Column(
      children: [
        // Header with week range and navigation
        _buildHeader(context, provider, weekStart),
        const SizedBox(height: 16),
        // Main content: Time grid on left, task lists on right
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Week grid takes most space
              Expanded(
                flex: 4,
                child: _buildWeekGrid(context, provider, weekDays),
              ),
              const SizedBox(width: 16),
              // Task lists on the right
              SizedBox(width: 180, child: _buildRightPanel(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DayCrafterProvider provider,
    DateTime weekStart,
  ) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final monthYear = DateFormat('MMM yyyy').format(weekStart);
    final dateRange =
        '${DateFormat('d').format(weekStart)} - ${DateFormat('d').format(weekEnd)}';

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
      child: Row(
        children: [
          Text(
            '$monthYear  $dateRange',
            style: const TextStyle(
              fontSize: 24,
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
          // View toggle buttons
          _buildViewToggleCompact(provider),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => provider.setCalendarActive(false),
            icon: const Icon(LucideIcons.x),
            color: AppStyles.mTextSecondary,
          ),
        ],
      ),
    );
  }

  /// Helper to parse time string "HH:MM" to minutes from midnight
  int _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return -1;
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return hour * 60 + minute;
    } catch (e) {
      return -1;
    }
  }

  Widget _buildWeekGrid(
    BuildContext context,
    DayCrafterProvider provider,
    List<DateTime> weekDays,
  ) {
    // Time slots from 7 AM to 9 PM
    final startHour = 7;
    final endHour = 22; // 10 PM
    final hoursCount = endHour - startHour;
    final hourHeight = 60.0;
    final totalHeight = hoursCount * hourHeight;
    final today = DateTime.now();

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
      child: Column(
        children: [
          // Day headers
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppStyles.mTextSecondary.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                // Empty space for time column
                const SizedBox(width: 50),
                // Day columns
                ...weekDays.map((day) {
                  final isToday =
                      day.year == today.year &&
                      day.month == today.month &&
                      day.day == today.day;
                  final isSelected =
                      day.year == provider.selectedDate.year &&
                      day.month == provider.selectedDate.month &&
                      day.day == provider.selectedDate.day;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => provider.setSelectedDate(day),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E').format(day),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isToday
                                  ? AppStyles.mPrimary
                                  : AppStyles.mTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppStyles.mPrimary
                                  : (isToday
                                        ? AppStyles.mSecondary.withValues(
                                            alpha: 0.3,
                                          )
                                        : Colors.transparent),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                day.day.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isToday
                                            ? AppStyles.mPrimary
                                            : AppStyles.mTextPrimary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // All-Day / Unscheduled Tasks Row
          _buildAllDayTasksRow(context, provider, weekDays),

          // Scrollable Time Grid
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: totalHeight,
                child: Stack(
                  children: [
                    // 1. Grid Lines and Time Labels
                    Column(
                      children: List.generate(hoursCount, (index) {
                        final hour = startHour + index;
                        final timeLabel = hour < 12
                            ? '${hour == 0 ? 12 : hour} AM'
                            : '${hour == 12 ? 12 : hour - 12} PM';

                        return Container(
                          height: hourHeight,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppStyles.mTextSecondary.withValues(
                                  alpha: 0.1,
                                ),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time Label
                              SizedBox(
                                width: 50,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    right: 8,
                                  ),
                                  child: Text(
                                    timeLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppStyles.mTextSecondary,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              // Vertical Dividers for Days
                              Expanded(
                                child: Row(
                                  children: List.generate(
                                    7,
                                    (i) => Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: AppStyles.mTextSecondary
                                                  .withValues(alpha: 0.1),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                    // 2. Task Blocks
                    // We need a layout builder to get the width of each day column
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final dayWidth = (constraints.maxWidth - 50) / 7;

                          // Collect all tasks to render
                          final allTaskWidgets = <Widget>[];

                          for (int i = 0; i < 7; i++) {
                            final day = weekDays[i];
                            final tasks = provider.getTasksForDate(day);

                            for (final task in tasks) {
                              final startTime = _parseTimeToMinutes(
                                task['start_time'],
                              );
                              final endTime = _parseTimeToMinutes(
                                task['end_time'],
                              );

                              // Skip if no valid time or all day (placeholder logic for all day)
                              if (startTime == -1 || endTime == -1) continue;

                              // Calculate position relative to grid start
                              final startMinute = startTime - (startHour * 60);
                              final durationMinutes = endTime - startTime;

                              if (startMinute < 0)
                                continue; // Starts before view

                              final top = (startMinute / 60) * hourHeight;
                              final height =
                                  (durationMinutes / 60) * hourHeight;

                              // Clamp height/top if needed? For now assume valid times

                              final priority = task['priority'] is int
                                  ? task['priority']
                                  : int.tryParse(
                                          task['priority']?.toString() ?? '3',
                                        ) ??
                                        3;
                              final priorityColor = AppStyles.getPriorityColor(
                                priority,
                              );
                              final isCompleted = task['isCompleted'] == true;

                              allTaskWidgets.add(
                                Positioned(
                                  left:
                                      50 + (i * dayWidth) + 1, // +1 for border
                                  top: top,
                                  width: dayWidth - 2, // -2 for margin
                                  height: height > 20
                                      ? height
                                      : 20, // Min height
                                  child: GestureDetector(
                                    onTap: () {
                                      final taskId = task['id']?.toString();
                                      if (taskId != null) {
                                        provider.toggleTaskCompletion(taskId);
                                      }
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        margin: const EdgeInsets.all(1),
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: priorityColor.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: priorityColor.withValues(
                                              alpha: 0.5,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                task['task']?.toString() ??
                                                    'Untitled',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppStyles.mTextPrimary,
                                                  decoration: isCompleted
                                                      ? TextDecoration
                                                            .lineThrough
                                                      : null,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (height >
                                                30) // Only show time if enough space
                                              Text(
                                                '${task['start_time']} - ${task['end_time']}',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color:
                                                      AppStyles.mTextSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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

                          return Stack(children: allTaskWidgets);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a row showing tasks that don't have valid start/end times
  Widget _buildAllDayTasksRow(
    BuildContext context,
    DayCrafterProvider provider,
    List<DateTime> weekDays,
  ) {
    // Check if there are any tasks without times
    bool hasAnyTasks = false;
    for (final day in weekDays) {
      final tasks = provider.getTasksForDate(day);
      for (final task in tasks) {
        final startTime = _parseTimeToMinutes(task['start_time']);
        if (startTime == -1) {
          hasAnyTasks = true;
          break;
        }
      }
      if (hasAnyTasks) break;
    }

    if (!hasAnyTasks) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppStyles.mTextSecondary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label
            SizedBox(
              width: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  'All Day',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppStyles.mTextSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            // Day columns
            ...weekDays.map((day) {
              final tasks = provider.getTasksForDate(day);
              // Filter to only tasks without times
              final allDayTasks = tasks.where((t) {
                final st = _parseTimeToMinutes(t['start_time']);
                return st == -1;
              }).toList();

              if (allDayTasks.isEmpty) {
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppStyles.mTextSecondary.withValues(
                            alpha: 0.1,
                          ),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const SizedBox(height: 30),
                  ),
                );
              }

              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: AppStyles.mTextSecondary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: allDayTasks.take(2).map((task) {
                      final priority = task['priority'] is int
                          ? task['priority']
                          : int.tryParse(task['priority']?.toString() ?? '3') ??
                                3;
                      final priorityColor = AppStyles.getPriorityColor(
                        priority,
                      );
                      final isCompleted = task['isCompleted'] == true;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Tooltip(
                          message: task['task']?.toString() ?? 'Untitled',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: priorityColor.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              task['task']?.toString() ?? 'Untitled',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppStyles.mTextPrimary,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    return Column(
      children: [
        // Today's List
        Expanded(
          child: _TaskListCard(
            title: "Today's List",
            date: today,
            icon: LucideIcons.calendar,
          ),
        ),
        const SizedBox(height: 12),
        // Tomorrow's List
        Expanded(
          child: _TaskListCard(
            title: "Tomorrow's List",
            date: tomorrow,
            icon: LucideIcons.calendarPlus,
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggleCompact(DayCrafterProvider provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewToggleButton(
          label: 'Day',
          isActive: provider.currentCalendarView == CalendarViewType.day,
          onTap: () => provider.setCalendarView(CalendarViewType.day),
          compact: true,
        ),
        const SizedBox(width: 4),
        _ViewToggleButton(
          label: 'Week',
          isActive: provider.currentCalendarView == CalendarViewType.week,
          onTap: () => provider.setCalendarView(CalendarViewType.week),
          compact: true,
        ),
        const SizedBox(width: 4),
        _ViewToggleButton(
          label: 'Month',
          isActive: provider.currentCalendarView == CalendarViewType.month,
          onTap: () => provider.setCalendarView(CalendarViewType.month),
          compact: true,
        ),
      ],
    );
  }
}

class _TaskListCard extends StatelessWidget {
  final String title;
  final DateTime date;
  final IconData icon;

  const _TaskListCard({
    required this.title,
    required this.date,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final tasks = provider.getTasksForDate(date);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppStyles.mSurface,
        borderRadius: AppStyles.bRadiusSmall,
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
              Icon(icon, size: 16, color: AppStyles.mPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title (${tasks.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.mTextPrimary,
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
                      'No tasks',
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
                          onTap: () {
                            final taskId = task['id']?.toString();
                            if (taskId != null) {
                              provider.toggleTaskCompletion(taskId);
                            }
                          },
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
