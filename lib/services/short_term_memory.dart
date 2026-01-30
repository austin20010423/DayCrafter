import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Internal message class for token-efficient short-term memory
class _MemoryMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  _MemoryMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory _MemoryMessage.fromJson(Map<String, dynamic> json) => _MemoryMessage(
    role: json['role'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

/// Token-efficient short-term memory for conversation context
/// Maintains last N messages with automatic token counting and summarization
class ShortTermMemory {
  final int maxMessages; // Max recent messages to keep
  final int maxTokens; // Max tokens for memory window
  
  final List<_MemoryMessage> _messages = [];
  int _estimatedTokens = 0;

  // Track message summaries for token efficiency
  final Map<String, String> _messageSummaries = {};

  ShortTermMemory({
    this.maxMessages = 10, // Keep last 10 messages by default
    this.maxTokens = 4000, // ~4k tokens window (token-efficient)
  });

  /// Add a message to memory
  void addMessage(String content, String role) {
    final message = _MemoryMessage(
      role: role.toLowerCase() == 'user' ? 'user' : 'assistant',
      content: content,
      timestamp: DateTime.now(),
    );
    
    _messages.add(message);
    _estimatedTokens += _estimateTokens(content);
    
    // Enforce memory limits
    _enforceMemoryLimits();
  }

  /// Add a message with ID for tracking
  void addMessageWithId(String id, String content, String role) {
    addMessage(content, role);
    _messageSummaries[id] = _summarizeMessage(content);
  }

  /// Get all messages in chat format
  List<Map<String, String>> getMessages() {
    return _messages.map((msg) {
      return {
        'role': msg.role,
        'content': msg.content,
      };
    }).toList();
  }

  /// Get system prompt with memory context (token-efficient)
  String getSystemPrompt({String? projectName}) {
    final recentContext = _buildTokenEfficientContext();
    
    return '''You are a Project Manager assistant with access to recent project history.

RECENT CONTEXT (Last messages in thread):
$recentContext

IMPORTANT: 
1. Reference previous messages when relevant
2. Build upon previous plans rather than starting fresh
3. Use the MCP tool for task planning/scheduling requests
4. Maintain consistency with established context''';
  }

  /// Get formatted conversation history for LLM
  String getFormattedHistory() {
    return _messages.asMap().entries.map((entry) {
      final idx = entry.key;
      final msg = entry.value;
      final role = msg.role == 'user' ? 'User' : 'Assistant';
      return '[$idx] $role: ${msg.content}';
    }).join('\n');
  }

  /// Clear all memory
  void clear() {
    _messages.clear();
    _messageSummaries.clear();
    _estimatedTokens = 0;
  }

  /// Get current estimated tokens
  int getEstimatedTokens() => _estimatedTokens;

  /// Get number of messages
  int getMessageCount() => _messages.length;

  /// Get last N messages as context string
  String getLastNMessagesContext(int n) {
    final recent = _messages.length > n
        ? _messages.sublist(_messages.length - n)
        : _messages;
    
    return recent.asMap().entries.map((entry) {
      final msg = entry.value;
      final role = msg.role == 'user' ? 'User' : 'Assistant';
      return '$role: ${msg.content}';
    }).join('\n\n');
  }

  /// Export memory to JSON for persistence
  String exportToJson() {
    final data = {
      'messages': _messages.map((msg) => msg.toJson()).toList(),
      'estimated_tokens': _estimatedTokens,
      'summaries': _messageSummaries,
    };
    return jsonEncode(data);
  }

  /// Import memory from JSON
  void importFromJson(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _messages.clear();
      _messageSummaries.clear();
      
      final messages = data['messages'] as List<dynamic>?;
      if (messages != null) {
        for (final msgData in messages) {
          _messages.add(_MemoryMessage.fromJson(msgData as Map<String, dynamic>));
        }
      }
      
      final summaries = data['summaries'] as Map<String, dynamic>?;
      if (summaries != null) {
        _messageSummaries.addAll(summaries.map(
          (k, v) => MapEntry(k, v.toString()),
        ));
      }

      // Recalculate tokens
      _estimatedTokens = _messages.fold(0, (sum, msg) => sum + _estimateTokens(msg.content));
    } catch (e) {
      debugPrint('Error importing memory from JSON: $e');
    }
  }

  /// Estimate tokens for content (approximation: ~1 token per 4 chars)
  int _estimateTokens(String content) {
    return (content.length / 4).ceil();
  }

  /// Enforce memory limits (remove oldest messages if exceeding limits)
  void _enforceMemoryLimits() {
    // Remove messages if exceeding token limit
    while (_estimatedTokens > maxTokens && _messages.isNotEmpty) {
      final removed = _messages.removeAt(0);
      _estimatedTokens -= _estimateTokens(removed.content);
    }

    // Remove oldest messages if exceeding message count
    while (_messages.length > maxMessages) {
      final removed = _messages.removeAt(0);
      _estimatedTokens -= _estimateTokens(removed.content);
    }
  }

  /// Summarize a message for token efficiency
  String _summarizeMessage(String content) {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }

  /// Build token-efficient context from recent messages
  String _buildTokenEfficientContext() {
    if (_messages.isEmpty) return '[No previous context]';
    
    // Get last 5 messages to stay token efficient
    final recentMsgs = _messages.length > 5
        ? _messages.sublist(_messages.length - 5)
        : _messages;
    
    return recentMsgs.asMap().entries.map((entry) {
      final msg = entry.value;
      final role = msg.role == 'user' ? 'User' : 'Assistant';
      final summary = _summarizeMessage(msg.content);
      return '• $role: $summary';
    }).join('\n');
  }
}

/// Extension for easy message creation
extension StringToMessage on String {
  Map<String, String> get asUserMessage => {
    'role': 'user',
    'content': this,
  };

  Map<String, String> get asAIMessage => {
    'role': 'assistant',
    'content': this,
  };
}
