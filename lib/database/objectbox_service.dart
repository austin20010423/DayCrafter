import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';
import '../objectbox.g.dart';
import 'objectbox_entities.dart';
import '../models.dart';

/// ObjectBox database service for managing local data storage
/// with vector search capabilities for semantic search
class ObjectBoxService {
  static ObjectBoxService? _instance;
  Store? _store;
  Box<ProjectEntity>? _projectBox;
  Box<MessageEntity>? _messageBox;
  Box<CalendarTaskEntity>? _calendarTaskBox;

  bool _isInitialized = false;

  /// Check if ObjectBox is ready to use
  bool get isInitialized => _isInitialized;

  /// Get store (throws if not initialized)
  Store get store => _store!;
  Box<ProjectEntity> get projectBox => _projectBox!;
  Box<MessageEntity> get messageBox => _messageBox!;
  Box<CalendarTaskEntity> get calendarTaskBox => _calendarTaskBox!;

  ObjectBoxService._();

  /// Singleton instance
  static ObjectBoxService get instance {
    _instance ??= ObjectBoxService._();
    return _instance!;
  }

  /// Initialize the ObjectBox store
  /// Should be called once at app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Use Application Support directory for macOS sandbox compatibility
    // This directory is always accessible by sandboxed apps
    final appSupportDir = await getApplicationSupportDirectory();
    _store = await openStore(directory: '${appSupportDir.path}/objectbox');
    _projectBox = _store!.box<ProjectEntity>();
    _messageBox = _store!.box<MessageEntity>();
    _calendarTaskBox = _store!.box<CalendarTaskEntity>();
    _isInitialized = true;
  }

  /// Close the store when app is shutting down
  void close() {
    if (_isInitialized && _store != null) {
      _store!.close();
      _isInitialized = false;
    }
  }

  /// Wipe all data (for testing/reset)
  void clearAllData() {
    if (!_isInitialized) return;
    debugPrint('🔥 Wiping all data from database...');
    _projectBox?.removeAll();
    _messageBox?.removeAll();
    _calendarTaskBox?.removeAll();
    debugPrint('✨ Database cleared');
  }

  // ============= Project Operations =============

  /// Save a new project
  int saveProject(ProjectEntity project) {
    return projectBox.put(project);
  }

  /// Get all projects for a specific user
  List<ProjectEntity> getAllProjects({String? userEmail}) {
    final all = projectBox.getAll();
    if (userEmail == null) return all;
    return all.where((p) => p.userEmail == userEmail).toList();
  }

  /// Get a project by its UUID
  ProjectEntity? getProjectByUuid(String uuid) {
    final query = projectBox.query(ProjectEntity_.uuid.equals(uuid)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  /// Delete a project by UUID
  bool deleteProjectByUuid(String uuid) {
    final entity = getProjectByUuid(uuid);
    if (entity != null) {
      // Delete all associated messages first
      for (final message in entity.messages) {
        messageBox.remove(message.id);
      }

      // Delete all associated calendar tasks
      deleteCalendarTasksForProject(uuid);

      return projectBox.remove(entity.id);
    }
    return false;
  }

  /// Update a project
  int updateProject(ProjectEntity project) {
    return projectBox.put(project);
  }

  // ============= Message Operations =============

  /// Save a new message with its embedding
  int saveMessage(MessageEntity message, {List<double>? embedding}) {
    if (embedding != null) {
      message.embedding = embedding;
    }
    return messageBox.put(message);
  }

  /// Get a message by its UUID
  MessageEntity? getMessageByUuid(String uuid) {
    final query = messageBox.query(MessageEntity_.uuid.equals(uuid)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  /// Get all messages for a project
  List<MessageEntity> getMessagesForProject(int projectId) {
    final query = messageBox
        .query(MessageEntity_.project.equals(projectId))
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Update a message
  int updateMessage(MessageEntity message) {
    return messageBox.put(message);
  }

  /// Delete a message by UUID
  bool deleteMessageByUuid(String uuid) {
    final entity = getMessageByUuid(uuid);
    if (entity != null) {
      return messageBox.remove(entity.id);
    }
    return false;
  }

  // ============= Calendar Task Operations =============

  /// Save a calendar task
  int saveCalendarTask(CalendarTaskEntity task) {
    // Check if task with same UUID exists
    // Using getAll for reliability
    final allTasks = calendarTaskBox.getAll();
    try {
      final existing = allTasks.firstWhere((t) => t.uuid == task.uuid);
      task.id = existing.id; // Update existing
      debugPrint('found existing task with id: ${existing.id}');
    } catch (_) {
      // Not found, new task
    }

    return calendarTaskBox.put(task);
  }

  /// Save multiple calendar tasks
  void saveCalendarTasks(List<CalendarTaskEntity> tasks) {
    // Deduplicate input list by UUID to prevent batch errors
    final uniqueTasks = <String, CalendarTaskEntity>{};
    for (final task in tasks) {
      uniqueTasks[task.uuid] = task;
    }
    final deduplicatedList = uniqueTasks.values.toList();

    // Process each task individually to avoid unique constraint violations
    for (final task in deduplicatedList) {
      // Try to find existing task by UUID
      final query = calendarTaskBox
          .query(CalendarTaskEntity_.uuid.equals(task.uuid))
          .build();
      final existing = query.findFirst();
      query.close();

      if (existing != null) {
        task.id = existing.id;
      } else {
        task.id = 0; // Ensure ID is 0 for new tasks
      }
    }

    try {
      calendarTaskBox.putMany(deduplicatedList);
    } catch (e) {
      debugPrint('❌ Batch save failed: $e. Retrying individually...');
      for (final task in deduplicatedList) {
        try {
          calendarTaskBox.put(task);
        } catch (innerE) {
          debugPrint('  - Failed to save task ${task.taskName}: $innerE');
        }
      }
    }
  }

  /// Get all calendar tasks for a specific user
  List<CalendarTaskEntity> getAllCalendarTasks({String? userEmail}) {
    final all = calendarTaskBox.getAll();
    if (userEmail == null) return all;
    return all.where((t) => t.userEmail == userEmail).toList();
  }

  /// Get calendar tasks for a specific date
  List<CalendarTaskEntity> getTasksForDate(DateTime date, {String? userEmail}) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get all tasks and filter by date (simpler and more reliable)
    final allTasks = calendarTaskBox.getAll();
    return allTasks.where((task) {
      // Filter by user if specified
      if (userEmail != null && task.userEmail != userEmail) return false;

      final taskDate = task.calendarDate;
      return taskDate.isAfter(
            startOfDay.subtract(const Duration(milliseconds: 1)),
          ) &&
          taskDate.isBefore(endOfDay);
    }).toList();
  }

  /// Get calendar tasks for a date range
  List<CalendarTaskEntity> getTasksForDateRange(
    DateTime start,
    DateTime end, {
    String? userEmail,
  }) {
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));

    // Get all tasks and filter by date range
    final allTasks = calendarTaskBox.getAll();
    return allTasks.where((task) {
      // Filter by user if specified
      if (userEmail != null && task.userEmail != userEmail) return false;

      final taskDate = task.calendarDate;
      return taskDate.isAfter(
            startOfDay.subtract(const Duration(milliseconds: 1)),
          ) &&
          taskDate.isBefore(endOfDay);
    }).toList();
  }

  /// Get a calendar task by UUID
  CalendarTaskEntity? getCalendarTaskByUuid(String uuid) {
    final query = calendarTaskBox
        .query(CalendarTaskEntity_.uuid.equals(uuid))
        .build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  /// Update a calendar task
  int updateCalendarTask(CalendarTaskEntity task) {
    return calendarTaskBox.put(task);
  }

  /// Delete a calendar task by UUID
  bool deleteCalendarTaskByUuid(String uuid) {
    final entity = getCalendarTaskByUuid(uuid);
    if (entity != null) {
      return calendarTaskBox.remove(entity.id);
    }
    return false;
  }

  /// Delete all calendar tasks for a specific project
  void deleteCalendarTasksForProject(String projectId) {
    final query = calendarTaskBox
        .query(CalendarTaskEntity_.projectId.equals(projectId))
        .build();
    final tasks = query.find();

    debugPrint('🗑️ FOUND ${tasks.length} tasks for project $projectId');
    for (var t in tasks) {
      debugPrint('  - Will delete task: ${t.taskName} (UUID: ${t.uuid})');
    }

    calendarTaskBox.removeMany(tasks.map((t) => t.id).toList());
    debugPrint('🗑️ Deleted tasks successfully');
    query.close();
  }

  /// Toggle task completion status
  void toggleTaskCompletion(String uuid) {
    final task = getCalendarTaskByUuid(uuid);
    if (task != null) {
      task.isCompleted = !task.isCompleted;
      calendarTaskBox.put(task);
    }
  }

  /// Search calendar tasks by text query with optional date range filter
  List<CalendarTaskEntity> searchTasksByText(
    String query, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final lowercaseQuery = query.toLowerCase();

    // Get all tasks and filter by text match
    var allTasks = calendarTaskBox.getAll();

    // Filter by text match (task name or description)
    var filtered = allTasks.where((task) {
      final nameMatch = task.taskName.toLowerCase().contains(lowercaseQuery);
      final descMatch =
          task.description?.toLowerCase().contains(lowercaseQuery) ?? false;
      return nameMatch || descMatch;
    });

    // Apply date range filter if provided
    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      filtered = filtered.where((task) => !task.calendarDate.isBefore(start));
    }

    if (endDate != null) {
      final end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      ).add(const Duration(days: 1));
      filtered = filtered.where((task) => task.calendarDate.isBefore(end));
    }

    return filtered.toList();
  }

  // ============= Semantic Search Operations =============

  /// Perform semantic search using vector similarity
  /// Returns messages sorted by similarity to the query embedding
  List<MessageEntity> semanticSearch(
    List<double> queryEmbedding, {
    int limit = 10,
    int? projectId,
  }) {
    // Build the nearest neighbor query
    final queryBuilder = messageBox.query(
      MessageEntity_.embedding.nearestNeighborsF32(queryEmbedding, limit * 2),
    );

    // Optionally filter by project
    if (projectId != null) {
      queryBuilder.link(
        MessageEntity_.project,
        ProjectEntity_.id.equals(projectId),
      );
    }

    final query = queryBuilder.build();
    final results = query.find();
    query.close();

    // Return top results (limit)
    return results.take(limit).toList();
  }

  /// Search for messages with embeddings similar to the query
  /// Returns messages with their similarity scores
  List<({MessageEntity message, double score})> semanticSearchWithScores(
    List<double> queryEmbedding, {
    int limit = 10,
    int? projectId,
  }) {
    final results = semanticSearch(
      queryEmbedding,
      limit: limit,
      projectId: projectId,
    );

    // Calculate cosine similarity scores
    return results.map((message) {
      final score = message.embedding != null
          ? _cosineSimilarity(queryEmbedding, message.embedding!)
          : 0.0;
      return (message: message, score: score);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = (normA > 0 && normB > 0)
        ? math.sqrt(normA * normB)
        : 1.0;
    return dotProduct / denominator;
  }

  // ============= Conversion Helpers =============

  /// Convert domain Project to entity and save
  Future<ProjectEntity> saveProjectFromDomain(
    Project project, {
    String? userEmail,
  }) async {
    // Check if project already exists
    var entity = getProjectByUuid(project.id);

    if (entity != null) {
      // Update existing project
      entity.name = project.name;
      entity.description = project.description;
      entity.colorHex = project.colorHex;
      // Don't overwrite existing userEmail unless specified
      if (userEmail != null) entity.userEmail = userEmail;
    } else {
      // Create new project
      entity = ProjectEntity.fromProject(project);
      entity.userEmail = userEmail;
    }

    projectBox.put(entity);
    return entity;
  }

  /// Convert domain Message to entity and save with embedding
  Future<MessageEntity> saveMessageFromDomain(
    Message message,
    ProjectEntity projectEntity, {
    List<double>? embedding,
  }) async {
    // Check if message already exists
    var entity = getMessageByUuid(message.id);

    if (entity != null) {
      // Update existing message
      entity.text = message.text;
      entity.tasksJson = message.tasks != null
          ? message.tasks.toString()
          : null;
      if (embedding != null) {
        entity.embedding = embedding;
      }
    } else {
      // Create new message
      entity = MessageEntity.fromMessage(message);
      entity.project.target = projectEntity;
      if (embedding != null) {
        entity.embedding = embedding;
      }
    }

    messageBox.put(entity);
    return entity;
  }

  /// Load all projects as domain models
  List<Project> loadAllProjectsAsDomain() {
    return getAllProjects().map((e) => e.toProject()).toList();
  }
}
