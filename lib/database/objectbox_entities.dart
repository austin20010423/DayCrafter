import 'dart:convert';
import 'package:objectbox/objectbox.dart';
import '../models.dart';

/// ObjectBox entity for Project with relationship to messages
@Entity()
class ProjectEntity {
  @Id()
  int id = 0;

  /// Original string UUID from the Project model
  @Unique()
  String uuid;

  String name;
  String description;
  String createdAt;
  String? colorHex;

  /// Relationship to messages
  @Backlink('project')
  final messages = ToMany<MessageEntity>();

  ProjectEntity({
    this.id = 0,
    required this.uuid,
    required this.name,
    required this.description,
    required this.createdAt,
    this.colorHex,
  });

  /// Convert from domain Project model
  factory ProjectEntity.fromProject(Project project) {
    return ProjectEntity(
      uuid: project.id,
      name: project.name,
      description: project.description,
      createdAt: project.createdAt,
      colorHex: project.colorHex,
    );
  }

  /// Convert to domain Project model (messages need to be loaded separately)
  Project toProject() {
    return Project(
      id: uuid,
      name: name,
      description: description,
      createdAt: createdAt,
      colorHex: colorHex,
      messages: messages.map((m) => m.toMessage()).toList(),
    );
  }
}

/// ObjectBox entity for Message with vector embedding for semantic search
@Entity()
class MessageEntity {
  @Id()
  int id = 0;

  /// Original string UUID from the Message model
  @Unique()
  String uuid;

  /// Role: 'user' or 'model'
  String role;

  /// Message text content
  String text;

  /// Timestamp as milliseconds since epoch
  @Property(type: PropertyType.date)
  DateTime timestamp;

  /// JSON-serialized tasks list
  String? tasksJson;

  /// Vector embedding for semantic search (1536 dimensions for OpenAI text-embedding-3-small)
  /// Using HNSW index for efficient approximate nearest neighbor search
  @HnswIndex(dimensions: 1536, neighborsPerNode: 30, indexingSearchCount: 200)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  /// Relationship to parent project
  final project = ToOne<ProjectEntity>();

  MessageEntity({
    this.id = 0,
    required this.uuid,
    required this.role,
    required this.text,
    required this.timestamp,
    this.tasksJson,
    this.embedding,
  });

  /// Convert from domain Message model
  factory MessageEntity.fromMessage(Message message) {
    return MessageEntity(
      uuid: message.id,
      role: message.role.name,
      text: message.text,
      timestamp: message.timestamp,
      tasksJson: message.tasks != null ? jsonEncode(message.tasks) : null,
    );
  }

  /// Convert to domain Message model
  Message toMessage() {
    return Message(
      id: uuid,
      role: MessageRole.values.byName(role),
      text: text,
      timestamp: timestamp,
      tasks: tasksJson != null
          ? List<Map<String, dynamic>>.from(jsonDecode(tasksJson!))
          : null,
    );
  }
}

/// ObjectBox entity for Calendar Tasks (submitted tasks)
@Entity()
class CalendarTaskEntity {
  @Id()
  int id = 0;

  /// Unique task identifier (composite ID for split tasks)
  @Unique()
  String uuid;

  /// Original API Task ID (to group split tasks)
  String? originalTaskId;

  /// Task name/title
  String taskName;

  /// Task description
  String? description;

  /// Due date for the task (Overall deadline)
  @Property(type: PropertyType.date)
  DateTime? dueDate;

  /// Date to show on calendar (Specific instance date)
  @Property(type: PropertyType.date)
  DateTime calendarDate;

  /// Start time string (e.g. "09:00")
  String? startTime;

  /// End time string (e.g. "09:30")
  String? endTime;

  /// Priority level (1=high, 2=medium, 3=low)
  int priority;

  /// Time to complete in days (from original task)
  int? timeToComplete;

  /// Related links
  String? links;

  /// Project ID this task belongs to
  String? projectId;

  /// Message ID this task came from
  String? messageId;

  /// Whether the task is completed
  bool isCompleted;

  /// Created timestamp
  @Property(type: PropertyType.date)
  DateTime createdAt;

  CalendarTaskEntity({
    this.id = 0,
    required this.uuid,
    this.originalTaskId,
    required this.taskName,
    this.description,
    this.dueDate,
    required this.calendarDate,
    this.startTime,
    this.endTime,
    required this.priority,
    this.timeToComplete,
    this.links,
    this.projectId,
    this.messageId,
    this.isCompleted = false,
    required this.createdAt,
  });

  /// Generate a list of task instances, one for each day between [start] and [end]
  static List<CalendarTaskEntity> fromTaskMapExpanded(
    Map<String, dynamic> task, {
    String? projectId,
    String? messageId,
  }) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty || dateStr == '-') return null;
      try {
        // Try parsing format like "2026-01-20"
        final parsed = DateTime.parse(dateStr);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {
        return null; // Simplified fallback for brevity, relying on basic ISO/parsable formats
      }
    }

    final originalId =
        task['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // 1. Determine Start Date (dateOnCalendar)
    final startStr = task['dateOnCalendar']?.toString();
    DateTime startDate =
        parseDate(startStr) ??
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // 2. Determine End Date (DueDate) - Default to Start Date if missing/invalid
    final dueStr = task['DueDate']?.toString();
    DateTime endDate = parseDate(dueStr) ?? startDate;

    // Safety: If End < Start, swap or clamp? Let's assume Start -> End is valid.
    // If End < Start, just use Start.
    if (endDate.isBefore(startDate)) {
      endDate = startDate;
    }

    final instances = <CalendarTaskEntity>[];

    // 3. Iterate from Start to End
    DateTime current = startDate;
    // Iterate until current is after endDate.
    // Add logic to prevent infinite loops if dates are somewhat far apart?
    // Assuming reasonable range.
    while (!current.isAfter(endDate)) {
      // Create ID: originalId + "_" + YYYY-MM-DD
      final dateSuffix =
          "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
      final instanceUuid = "${originalId}_$dateSuffix";

      instances.add(
        CalendarTaskEntity(
          uuid: instanceUuid,
          originalTaskId: originalId,
          taskName: task['task']?.toString() ?? 'Untitled Task',
          description: task['Description']?.toString(),
          dueDate: endDate, // Keep original due date for reference
          calendarDate: current, // The specific day for this instance
          startTime: task['start_time']?.toString(),
          endTime: task['end_time']?.toString(),
          priority: task['priority'] is int
              ? task['priority']
              : int.tryParse(task['priority']?.toString() ?? '3') ?? 3,
          timeToComplete: task['TimeToComplete'] is int
              ? task['TimeToComplete']
              : int.tryParse(task['TimeToComplete']?.toString() ?? ''),
          links: task['links']?.toString(),
          projectId: projectId,
          messageId: messageId,
          isCompleted: false,
          createdAt: DateTime.now(),
        ),
      );

      // Next day
      current = current.add(const Duration(days: 1));
    }

    return instances;
  }

  /// BACKWARD COMPATIBILITY / SINGLE conversion (if needed)
  /// Deprecated: use fromTaskMapExpanded for multi-day support
  factory CalendarTaskEntity.fromTaskMap(
    Map<String, dynamic> task, {
    String? projectId,
    String? messageId,
  }) {
    // Just return the first instance from the expanded list
    final list = fromTaskMapExpanded(
      task,
      projectId: projectId,
      messageId: messageId,
    );
    if (list.isNotEmpty) return list.first;

    // Fallback empty (should not happen based on logic above)
    return CalendarTaskEntity(
      uuid: 'error',
      taskName: 'Error',
      calendarDate: DateTime.now(),
      priority: 3,
      createdAt: DateTime.now(),
    );
  }

  /// Convert to task map for display
  Map<String, dynamic> toTaskMap() {
    return {
      'id': originalTaskId ?? uuid, // Prefer original ID for display if grouped
      'uuid': uuid, // Verification
      'task': taskName,
      'Description': description,
      'DueDate': dueDate?.toIso8601String().split('T')[0],
      'dateOnCalendar': calendarDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'priority': priority,
      'TimeToComplete': timeToComplete,
      'links': links,
      'isCompleted': isCompleted,
      'projectId': projectId,
    };
  }
}
