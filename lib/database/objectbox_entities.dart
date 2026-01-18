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
