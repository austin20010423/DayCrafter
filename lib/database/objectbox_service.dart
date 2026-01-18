import 'dart:math' as math;
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

  bool _isInitialized = false;

  /// Check if ObjectBox is ready to use
  bool get isInitialized => _isInitialized;

  /// Get store (throws if not initialized)
  Store get store => _store!;
  Box<ProjectEntity> get projectBox => _projectBox!;
  Box<MessageEntity> get messageBox => _messageBox!;

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
    _isInitialized = true;
  }

  /// Close the store when app is shutting down
  void close() {
    if (_isInitialized && _store != null) {
      _store!.close();
      _isInitialized = false;
    }
  }

  // ============= Project Operations =============

  /// Save a new project
  int saveProject(ProjectEntity project) {
    return projectBox.put(project);
  }

  /// Get all projects
  List<ProjectEntity> getAllProjects() {
    return projectBox.getAll();
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
  Future<ProjectEntity> saveProjectFromDomain(Project project) async {
    // Check if project already exists
    var entity = getProjectByUuid(project.id);

    if (entity != null) {
      // Update existing project
      entity.name = project.name;
      entity.description = project.description;
      entity.colorHex = project.colorHex;
    } else {
      // Create new project
      entity = ProjectEntity.fromProject(project);
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
