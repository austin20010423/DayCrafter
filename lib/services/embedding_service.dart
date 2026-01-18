import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for generating text embeddings using OpenAI's API.
/// Uses the text-embedding-3-small model for efficient, high-quality embeddings.
class EmbeddingService {
  static EmbeddingService? _instance;

  /// Embedding dimension for text-embedding-3-small
  static const int embeddingDimension = 1536;

  /// OpenAI API endpoint for embeddings
  static const String _apiEndpoint = 'https://api.openai.com/v1/embeddings';

  /// Model to use for embeddings
  static const String _model = 'text-embedding-3-small';

  bool _isInitialized = false;
  String? _apiKey;

  EmbeddingService._();

  /// Singleton instance
  static EmbeddingService get instance {
    _instance ??= EmbeddingService._();
    return _instance!;
  }

  /// Check if the service is ready to generate embeddings
  bool get isReady => _isInitialized && _apiKey != null && _apiKey!.isNotEmpty;

  /// Initialize the embedding service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load API key from environment
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: ".env");
      }
      _apiKey = dotenv.env['OPENAI_API_KEY'];

      if (_apiKey == null || _apiKey!.isEmpty) {
        throw Exception('OPENAI_API_KEY not found in .env file');
      }

      _isInitialized = true;
      debugPrint('✅ Embedding service initialized (OpenAI API)');
    } catch (e) {
      debugPrint('⚠️ Embedding service initialization failed: $e');
      rethrow;
    }
  }

  /// Generate embedding for a text string
  /// Returns a 1536-dimensional vector
  Future<List<double>> generateEmbedding(String text) async {
    if (!isReady) {
      await initialize();
    }

    if (_apiKey == null) {
      throw StateError('API key not configured');
    }

    // Truncate very long text (API limit is ~8000 tokens for this model)
    final truncatedText = text.length > 8000 ? text.substring(0, 8000) : text;

    try {
      final response = await http.post(
        Uri.parse(_apiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({'model': _model, 'input': truncatedText}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final embedding = data['data'][0]['embedding'] as List<dynamic>;
        return embedding.map((e) => (e as num).toDouble()).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception('OpenAI API error: ${error['error']['message']}');
      }
    } catch (e) {
      debugPrint('Embedding generation error: $e');
      rethrow;
    }
  }

  /// Generate embeddings for multiple texts (batch processing)
  /// More efficient than calling generateEmbedding multiple times
  Future<List<List<double>>> generateEmbeddings(List<String> texts) async {
    if (!isReady) {
      await initialize();
    }

    if (_apiKey == null) {
      throw StateError('API key not configured');
    }

    // Truncate and prepare inputs
    final inputs = texts
        .map((t) => t.length > 8000 ? t.substring(0, 8000) : t)
        .toList();

    try {
      final response = await http.post(
        Uri.parse(_apiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({'model': _model, 'input': inputs}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final embeddings = (data['data'] as List<dynamic>).map((item) {
          final embedding = item['embedding'] as List<dynamic>;
          return embedding.map((e) => (e as num).toDouble()).toList();
        }).toList();
        return embeddings;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('OpenAI API error: ${error['error']['message']}');
      }
    } catch (e) {
      debugPrint('Batch embedding generation error: $e');
      rethrow;
    }
  }

  /// Dispose resources (nothing to dispose for API-based service)
  void dispose() {
    _isInitialized = false;
    _apiKey = null;
  }
}
