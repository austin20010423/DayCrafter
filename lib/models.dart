enum MessageRole { user, model }

class Message {
  final String id;
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  final List<Map<String, dynamic>>? tasks;

  Message({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.tasks,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'tasks': tasks,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: MessageRole.values.byName(json['role']),
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      tasks: json['tasks'] != null ? List<Map<String, dynamic>>.from(json['tasks']) : null,
    );
  }
}

class Project {
  final String id;
  final String name;
  final String description;
  final String createdAt;
  final String? colorHex;
  final List<Message> messages;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.colorHex,
    required this.messages,
  });

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? createdAt,
    String? colorHex,
    List<Message>? messages,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      colorHex: colorHex ?? this.colorHex,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt,
      'colorHex': colorHex,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdAt: json['createdAt'],
      colorHex: json['colorHex'],
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList(),
    );
  }
}
