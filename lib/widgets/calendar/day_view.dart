import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../provider.dart';
import '../../styles.dart';
import '../../l10n/app_localizations.dart';
import '../task_detail_dialog.dart';
import '../add_task_dialog.dart';

/// Day View - Default calendar view showing a single day with time slots
class DayView extends StatelessWidget {
  const DayView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final selectedDate = provider.selectedDate;

    return Column(
      children: [
        // Header with date and navigation (matching week/month view style)
        _buildHeader(context, provider, selectedDate),
        const SizedBox(height: 16),
        // All Day Tasks Section
        _buildAllDayTasks(context, provider, selectedDate),
        const SizedBox(height: 16),
        // Main content area
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left side: Date display + Time slots grid
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildDateDisplay(context, provider, selectedDate),
                    const SizedBox(height: 16),
                    Expanded(child: _buildTimeGrid(context, selectedDate)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right side: Mini calendar + AI Summary + Next Task
              SizedBox(
                width: 280,
                child: ClipRRect(
                  borderRadius: AppStyles.bRadiusMedium,
                  child: _buildRightPanel(context, provider, selectedDate),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Header bar matching the week/month view style
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
      child: Row(
        children: [
          Text(
            monthYear,
            style: TextStyle(
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
          // Add task button
          IconButton(
            onPressed: () =>
                AddTaskDialog.show(context, initialDate: provider.selectedDate),
            icon: const Icon(LucideIcons.plus),
            color: AppStyles.mPrimary,
            tooltip: AppLocalizations.of(context)!.addTask,
          ),
          const SizedBox(width: 8),
          // View toggle buttons
          _buildViewToggleCompact(context, provider),
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

  /// Date display showing the large day number (kept separate from header)
  Widget _buildDateDisplay(
    BuildContext context,
    DayCrafterProvider provider,
    DateTime selectedDate,
  ) {
    final dayNum = selectedDate.day.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
      child: Center(
        // Large date number - centered
        child: Text(
          dayNum,
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: AppStyles.mPrimary,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  // Helper to parse time string "HH:MM" to minutes from midnight
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

  Widget _buildAllDayTasks(
    BuildContext context,
    DayCrafterProvider provider,
    DateTime selectedDate,
  ) {
    final allTasks = provider.getTasksForDate(selectedDate);
    // Filter for tasks strictly without start/end times (All Day)
    // OR tasks where parsing failed (= -1)
    final tasks = allTasks.where((t) {
      final start = _parseTimeToMinutes(t['start_time']);
      return start == -1;
    }).toList();

    if (tasks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(LucideIcons.listTodo, size: 16, color: AppStyles.mPrimary),
                const SizedBox(width: 8),
                Text(
                  'Tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.mTextPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppStyles.mPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tasks.length.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.mPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tasks.map((task) {
                final priority = task['priority'] is int
                    ? task['priority']
                    : int.tryParse(task['priority']?.toString() ?? '3') ?? 3;
                final priorityColor = AppStyles.getPriorityColor(priority);
                final isCompleted = task['isCompleted'] == true;

                return InkWell(
                  onTap: () => TaskDetailDialog.show(context, task),
                  borderRadius: AppStyles.bRadiusSmall,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: AppStyles.bRadiusSmall,
                      border: Border.all(
                        color: priorityColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCompleted
                              ? LucideIcons.checkCircle
                              : LucideIcons.circle,
                          size: 14,
                          color: isCompleted
                              ? AppStyles.mAccent
                              : priorityColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (task['start_time'] != null &&
                                    task['end_time'] != null)
                                ? '${task['start_time']} - ${task['end_time']} ${task['task']?.toString() ?? 'Untitled'}'
                                : task['task']?.toString() ?? 'Untitled',
                            style: TextStyle(
                              fontSize: 12,
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
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeGrid(BuildContext context, DateTime selectedDate) {
    final provider = context.watch<DayCrafterProvider>();
    final allTasks = provider.getTasksForDate(selectedDate);

    // Time slots from 7 AM to 11 PM
    final startHour = 7;
    final endHour = 23;
    final hoursCount = endHour - startHour;
    final hourHeight = 80.0; // Keep the tall slots
    final totalHeight = hoursCount * hourHeight;
    final hours = List.generate(hoursCount, (index) => index + startHour);

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
      child: ClipRRect(
        borderRadius: AppStyles.bRadiusMedium,
        child: SingleChildScrollView(
          // Make it scrollable independently
          child: SizedBox(
            height: totalHeight,
            child: Stack(
              children: [
                // 1. Grid Lines and Time Labels (matching week view style)
                Column(
                  children: hours.map((hour) {
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
                              padding: const EdgeInsets.only(top: 8, right: 8),
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
                          // Expanded area for tasks
                          Expanded(
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
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // 2. Positioned Tasks
                Positioned.fill(
                  left: 50, // Offset by time column width
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final taskWidgets = <Widget>[];

                      for (final task in allTasks) {
                        final startTime = _parseTimeToMinutes(
                          task['start_time'],
                        );
                        final endTime = _parseTimeToMinutes(task['end_time']);

                        if (startTime == -1 || endTime == -1) continue;

                        final startMinute = startTime - (startHour * 60);
                        final durationMinutes = endTime - startTime;

                        if (startMinute < 0) continue;

                        final top = (startMinute / 60) * hourHeight;
                        final height = (durationMinutes / 60) * hourHeight;

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

                        taskWidgets.add(
                          Positioned(
                            top: top,
                            left: 10,
                            right: 10, // Padding
                            height: height > 30 ? height : 30, // Min height
                            child: GestureDetector(
                              onTap: () => TaskDetailDialog.show(context, task),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border(
                                      left: BorderSide(
                                        color: priorityColor,
                                        width: 4,
                                      ),
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
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppStyles.mTextPrimary,
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (height > 45)
                                        Text(
                                          '${task['start_time']} - ${task['end_time']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppStyles.mTextSecondary,
                                            fontWeight: FontWeight.w500,
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

                      return Stack(children: taskWidgets);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(
    BuildContext context,
    DayCrafterProvider provider,
    DateTime selectedDate,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Mini Calendar
          _buildMiniCalendar(context, provider, selectedDate),
          const SizedBox(height: 16),
          // Tasks list
          _buildNextTask(context, provider, selectedDate),
        ],
      ),
    );
  }

  Widget _buildMiniCalendar(
    BuildContext context,
    DayCrafterProvider provider,
    DateTime selectedDate,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: selectedDate,
        selectedDayPredicate: (day) => isSameDay(day, selectedDate),
        onDaySelected: (selectedDay, focusedDay) {
          provider.setSelectedDate(selectedDay);
        },
        calendarFormat: CalendarFormat.month,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppStyles.mTextPrimary,
          ),
          leftChevronIcon: Icon(
            LucideIcons.chevronLeft,
            size: 16,
            color: AppStyles.mTextSecondary,
          ),
          rightChevronIcon: Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: AppStyles.mTextSecondary,
          ),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: AppStyles.mSecondary.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: AppStyles.mPrimary,
            shape: BoxShape.circle,
          ),
          defaultTextStyle: TextStyle(
            fontSize: 12,
            color: AppStyles.mTextPrimary,
          ),
          weekendTextStyle: TextStyle(
            fontSize: 12,
            color: AppStyles.mTextSecondary,
          ),
          outsideTextStyle: TextStyle(
            fontSize: 12,
            color: AppStyles.mTextSecondary.withValues(alpha: 0.5),
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppStyles.mTextSecondary,
          ),
          weekendStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppStyles.mTextSecondary.withValues(alpha: 0.7),
          ),
        ),
        rowHeight: 32,
        daysOfWeekHeight: 24,
      ),
    );
  }

  Widget _buildNextTask(
    BuildContext context,
    DayCrafterProvider provider,
    DateTime selectedDate,
  ) {
    final tasks = provider.getTasksForDate(selectedDate);

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(LucideIcons.listTodo, size: 18, color: AppStyles.mPrimary),
              const SizedBox(width: 8),
              Text(
                'Tasks (${tasks.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.mTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Text(
              'No tasks for this day',
              style: TextStyle(fontSize: 13, color: AppStyles.mTextSecondary),
            )
          else
            ...tasks.take(3).map((task) => _buildTaskItem(task, provider)),
          if (tasks.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${tasks.length - 3} more tasks',
                style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.mPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(
    Map<String, dynamic> task,
    DayCrafterProvider provider,
  ) {
    final priority = task['priority'] is int
        ? task['priority']
        : int.tryParse(task['priority']?.toString() ?? '3') ?? 3;
    final priorityColor = AppStyles.getPriorityColor(priority);
    final isCompleted = task['isCompleted'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          final taskId = task['id']?.toString();
          if (taskId != null) {
            provider.toggleTaskCompletion(taskId);
          }
        },
        borderRadius: AppStyles.bRadiusSmall,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: priorityColor.withValues(alpha: 0.1),
            borderRadius: AppStyles.bRadiusSmall,
            border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                isCompleted ? LucideIcons.checkCircle : LucideIcons.circle,
                size: 16,
                color: isCompleted ? AppStyles.mAccent : priorityColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (task['start_time'] != null && task['end_time'] != null)
                      ? '${task['start_time']} - ${task['end_time']} ${task['task']?.toString() ?? 'Untitled'}'
                      : task['task']?.toString() ?? 'Untitled',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.mTextPrimary,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
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
