// Standalone verification script using print/assert
// Copying code logic to verify without external deps

class CalendarTaskEntity {
  String uuid;
  String? originalTaskId;
  String taskName;
  DateTime calendarDate;
  DateTime? dueDate;
  String? startTime;
  String? endTime;

  CalendarTaskEntity({
    required this.uuid,
    this.originalTaskId,
    required this.taskName,
    required this.calendarDate,
    this.dueDate,
    this.startTime,
    this.endTime,
  });

  static List<CalendarTaskEntity> fromTaskMapExpanded(
    Map<String, dynamic> task,
  ) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty || dateStr == '-') return null;
      try {
        final parsed = DateTime.parse(dateStr);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {
        return null; // Simplified fallback
      }
    }

    final originalId = task['id']?.toString() ?? 'default_id';

    final startStr = task['dateOnCalendar']?.toString();
    DateTime startDate = parseDate(startStr) ?? DateTime.now();

    final dueStr = task['DueDate']?.toString();
    DateTime endDate = parseDate(dueStr) ?? startDate;

    if (endDate.isBefore(startDate)) {
      endDate = startDate;
    }

    final instances = <CalendarTaskEntity>[];
    DateTime current = startDate;

    // Use loop with safety limit just in case
    int safety = 0;
    while (!current.isAfter(endDate) && safety < 1000) {
      final dateSuffix =
          "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
      final instanceUuid = "${originalId}_$dateSuffix";

      instances.add(
        CalendarTaskEntity(
          uuid: instanceUuid,
          originalTaskId: originalId,
          taskName: task['task']?.toString() ?? 'Untitled',
          calendarDate: current,
          dueDate: endDate,
          startTime: task['start_time']?.toString(),
          endTime: task['end_time']?.toString(),
        ),
      );

      current = current.add(const Duration(days: 1));
      safety++;
    }

    return instances;
  }
}

void main() {
  print("Running verification...");

  // Test 1: 2-day Split
  final input = {
    "id": "task123",
    "dateOnCalendar": "2026-01-20",
    "DueDate": "2026-01-21",
    "start_time": "09:00",
    "end_time": "09:30",
    "task": "Test Task",
  };

  final results = CalendarTaskEntity.fromTaskMapExpanded(input);

  if (results.length != 2)
    throw "Error: Expected 2 results, got ${results.length}";

  // Day 1
  if (results[0].calendarDate != DateTime(2026, 1, 20))
    throw "Error: Day 1 date wrong";
  if (results[0].uuid != "task123_2026-01-20") throw "Error: Day 1 UUID wrong";

  // Day 2
  if (results[1].calendarDate != DateTime(2026, 1, 21))
    throw "Error: Day 2 date wrong";
  if (results[1].uuid != "task123_2026-01-21") throw "Error: Day 2 UUID wrong";

  print("Test 1 Passed: 2-day split correct.");

  // Test 2: Single Day
  final input2 = {
    "id": "task456",
    "dateOnCalendar": "2026-01-25",
    "DueDate": "2026-01-25",
    "task": "One Day",
  };

  final results2 = CalendarTaskEntity.fromTaskMapExpanded(input2);
  if (results2.length != 1) throw "Error: Expected 1 result for single day";
  if (results2[0].uuid != "task456_2026-01-25")
    throw "Error: Single day UUID wrong";

  print("Test 2 Passed: Single day correct.");

  print("ALL TESTS PASSED");
}
