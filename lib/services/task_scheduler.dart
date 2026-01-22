import '../database/objectbox_service.dart';
import '../database/objectbox_entities.dart';

/// Service for scheduling tasks across all projects
/// Resolves time conflicts and prioritizes high-priority tasks earlier
class TaskScheduler {
  static final TaskScheduler _instance = TaskScheduler._();
  static TaskScheduler get instance => _instance;
  TaskScheduler._();

  /// Configuration
  static const int defaultStartHour = 8; // 8 AM
  static const int defaultStartMinute = 0;
  static const int defaultTaskDurationMinutes = 30;

  /// Schedule new tasks for a specific date, resolving conflicts with existing tasks
  /// Returns the scheduled tasks with assigned time slots
  List<CalendarTaskEntity> scheduleTasksForDate(
    DateTime date,
    List<CalendarTaskEntity> newTasks,
  ) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return newTasks;

    // Get existing tasks for this date
    final existingTasks = db.getTasksForDate(date);

    // Separate manually scheduled tasks (they keep their times)
    final manualTasks = existingTasks
        .where((t) => t.isManuallyScheduled)
        .toList();
    final autoTasks = existingTasks
        .where((t) => !t.isManuallyScheduled)
        .toList();

    // Combine auto-scheduled existing tasks with new tasks
    final tasksToSchedule = [...autoTasks, ...newTasks];

    // Sort by priority (1 = highest priority first)
    tasksToSchedule.sort((a, b) => a.priority.compareTo(b.priority));

    // Get occupied time slots from manually scheduled tasks
    final occupiedSlots = _getOccupiedSlots(manualTasks);

    // Assign time slots to tasks
    var currentMinutes = defaultStartHour * 60 + defaultStartMinute;

    for (final task in tasksToSchedule) {
      // Get duration (default 30 min if not specified)
      final duration = _getTaskDuration(task);

      // Find next available slot
      currentMinutes = _findNextAvailableSlot(
        currentMinutes,
        duration,
        occupiedSlots,
      );

      // Assign time
      task.startTime = _minutesToTimeString(currentMinutes);
      task.endTime = _minutesToTimeString(currentMinutes + duration);

      // Mark as auto-scheduled
      task.isManuallyScheduled = false;

      // Add to occupied slots
      occupiedSlots.add((
        start: currentMinutes,
        end: currentMinutes + duration,
      ));

      // Move to next slot
      currentMinutes += duration;
    }

    return tasksToSchedule;
  }

  /// Re-schedule all tasks for a date (called after manual changes)
  void rescheduleDate(DateTime date) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return;

    final allTasks = db.getTasksForDate(date);

    // Only reschedule auto-scheduled tasks
    final manualTasks = allTasks.where((t) => t.isManuallyScheduled).toList();
    final autoTasks = allTasks.where((t) => !t.isManuallyScheduled).toList();

    if (autoTasks.isEmpty) return;

    // Sort by priority
    autoTasks.sort((a, b) => a.priority.compareTo(b.priority));

    // Get occupied slots from manual tasks
    final occupiedSlots = _getOccupiedSlots(manualTasks);

    var currentMinutes = defaultStartHour * 60 + defaultStartMinute;

    for (final task in autoTasks) {
      final duration = _getTaskDuration(task);
      currentMinutes = _findNextAvailableSlot(
        currentMinutes,
        duration,
        occupiedSlots,
      );

      task.startTime = _minutesToTimeString(currentMinutes);
      task.endTime = _minutesToTimeString(currentMinutes + duration);

      occupiedSlots.add((
        start: currentMinutes,
        end: currentMinutes + duration,
      ));
      currentMinutes += duration;
    }

    // Save updated tasks
    db.saveCalendarTasks(autoTasks);
  }

  /// Get task duration in minutes
  int _getTaskDuration(CalendarTaskEntity task) {
    // Try to parse from start/end time
    if (task.startTime != null && task.endTime != null) {
      final startMins = _parseTimeToMinutes(task.startTime!);
      final endMins = _parseTimeToMinutes(task.endTime!);
      if (startMins >= 0 && endMins > startMins) {
        return endMins - startMins;
      }
    }

    // Use timeToComplete if available (assuming it's in minutes)
    if (task.timeToComplete != null && task.timeToComplete! > 0) {
      return task.timeToComplete!;
    }

    // Default duration
    return defaultTaskDurationMinutes;
  }

  /// Get list of occupied time slots
  List<({int start, int end})> _getOccupiedSlots(
    List<CalendarTaskEntity> tasks,
  ) {
    final slots = <({int start, int end})>[];

    for (final task in tasks) {
      if (task.startTime != null && task.endTime != null) {
        final start = _parseTimeToMinutes(task.startTime!);
        final end = _parseTimeToMinutes(task.endTime!);
        if (start >= 0 && end > start) {
          slots.add((start: start, end: end));
        }
      }
    }

    // Sort by start time
    slots.sort((a, b) => a.start.compareTo(b.start));
    return slots;
  }

  /// Find next available slot that doesn't overlap with occupied slots
  int _findNextAvailableSlot(
    int preferredStart,
    int duration,
    List<({int start, int end})> occupiedSlots,
  ) {
    var start = preferredStart;

    for (final slot in occupiedSlots) {
      // Check if proposed slot overlaps with occupied slot
      final proposedEnd = start + duration;

      if (start < slot.end && proposedEnd > slot.start) {
        // Overlap detected, move start to after this slot
        start = slot.end;
      }
    }

    return start;
  }

  /// Parse time string "HH:MM" to minutes from midnight
  int _parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return hour * 60 + minute;
    } catch (_) {
      return -1;
    }
  }

  /// Convert minutes from midnight to "HH:MM" string
  String _minutesToTimeString(int minutes) {
    final hours = (minutes ~/ 60) % 24;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }
}
