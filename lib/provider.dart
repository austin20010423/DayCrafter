import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class DayCrafterProvider with ChangeNotifier {
  String? _userName;
  List<Project> _projects = [];
  String? _activeProjectId;
  bool _isLoading = false;

  // A small palette of colors (hex strings) for projects
  final List<String> _palette = [
    '#FF6B6B', // Red
    '#FFA94D', // Orange
    '#FFD43B', // Yellow
    '#6BCB77', // Green
    '#4D96FF', // Blue
    '#C77DFF', // Purple
    '#FF6FB5', // Pink
  ];

  String? get userName => _userName;
  List<Project> get projects => _projects;
  String? get activeProjectId => _activeProjectId;
  bool get isLoading => _isLoading;

  Project? get activeProject {
    if (_activeProjectId == null) return null;
    return _projects.firstWhere(
      (p) => p.id == _activeProjectId,
      orElse: () => _projects.first,
    );
  }

  DayCrafterProvider() {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('daycrafter_user_name');
    final projectsJson = prefs.getString('daycrafter_projects');
    if (projectsJson != null) {
      final List<dynamic> decoded = jsonDecode(projectsJson);
      _projects = decoded.map((p) => Project.fromJson(p)).toList();

      // Ensure every project has a color assigned (backfill older projects)
      final usedColors = _projects
          .where((p) => p.colorHex != null)
          .map((p) => p.colorHex!)
          .toSet();
      _projects = _projects.map((proj) {
        if (proj.colorHex == null) {
          final color = _palette.firstWhere(
            (c) => !usedColors.contains(c),
            orElse: () => _palette[0],
          );
          usedColors.add(color);
          return proj.copyWith(colorHex: color);
        }
        return proj;
      }).toList();
    }
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daycrafter_user_name', _userName!);
    notifyListeners();
  }

  Future<void> addProject(String name) async {
    final usedColors = _projects
        .map((p) => p.colorHex)
        .where((c) => c != null)
        .toSet();
    final availableColor = _palette.firstWhere(
      (color) => !usedColors.contains(color),
      orElse: () =>
          _palette[0], // If all used, use first (will repeat, but better than crash)
    );
    final newProject = Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: '',
      createdAt: DateTime.now().toString(), // Simple date string
      colorHex: availableColor,
      messages: [
        Message(
          id: 'welcome',
          role: MessageRole.model,
          text:
              "Hi! I'm your AI PM for **$name**. How can I help you plan, research, or manage tasks today?",
          timestamp: DateTime.now(),
        ),
      ],
    );
    _projects.add(newProject);
    _activeProjectId = newProject.id;
    await _saveProjects();
    notifyListeners();
  }

  void setActiveProject(String? id) {
    _activeProjectId = id;
    notifyListeners();
  }

  Future<void> sendMessage(String text, MessageRole role) async {
    if (_activeProjectId == null) return;

    final projectIndex = _projects.indexWhere((p) => p.id == _activeProjectId);
    if (projectIndex == -1) return;

    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: role,
      text: text,
      timestamp: DateTime.now(),
    );

    final updatedProject = _projects[projectIndex].copyWith(
      messages: [..._projects[projectIndex].messages, newMessage],
    );

    _projects[projectIndex] = updatedProject;
    await _saveProjects();
    notifyListeners();

    if (role == MessageRole.user) {
      // Set loading BEFORE making API calls so animation appears immediately
      _isLoading = true;
      notifyListeners();

      await _getTasks(text);
      await _getAiResponse(text);

      // Reset loading after all API calls complete
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _getAiResponse(String userText) async {
    debugPrint('Starting AI response...');

    try {
      // In a real app, this key should be secured (env var, etc.)
      const apiKey = String.fromEnvironment(
        'OPENAI_API_KEY',
        defaultValue: 'YOUR_OPENAI_API_KEY',
      );

      final openAI = OpenAI.instance.build(
        token: apiKey,
        baseOption: HttpSetup(
          receiveTimeout: const Duration(seconds: 30),
          connectTimeout: const Duration(seconds: 30),
        ),
      );

      final request = ChatCompleteText(
        model: GptTurboChatModel(),
        messages: [
          {
            "role": "system",
            "content":
                'You are a professional Project Manager assistant for the project "${activeProject?.name}". Help with planning, task breakdown, and research. Keep responses structured and professional.',
          },
          {"role": "user", "content": userText},
        ],
        maxToken: 1000,
      );

      final response = await openAI.onChatCompletion(request: request);

      final aiText =
          response?.choices.first.message?.content ??
          "I'm sorry, I couldn't generate a response.";

      await sendMessage(aiText, MessageRole.model);
    } catch (e) {
      debugPrint('AI Error: $e');
      await sendMessage(
        "Failed to connect to AI service. Please check your OpenAI API key.",
        MessageRole.model,
      );
    }
    debugPrint('AI response completed');
  }

  Future<void> _getTasks(String userText) async {
    debugPrint('Starting task API call...');
    try {
      final url = Uri.parse('http://127.0.0.1:8000/run');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'input_task': userText}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final resultString = data['result'] as String;
          final tasks = jsonDecode(resultString) as List<dynamic>;
          final taskList = tasks.map((t) => t as Map<String, dynamic>).toList();

          final taskMessage = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: MessageRole.model,
            text: 'Here are the planned tasks:',
            timestamp: DateTime.now(),
            tasks: taskList,
          );

          final projectIndex = _projects.indexWhere(
            (p) => p.id == _activeProjectId,
          );
          if (projectIndex != -1) {
            final updatedProject = _projects[projectIndex].copyWith(
              messages: [..._projects[projectIndex].messages, taskMessage],
            );
            _projects[projectIndex] = updatedProject;
            await _saveProjects();
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Task API Error: $e');
      // Add a message about task API failure with more specific error info
      String errorMessage = 'Failed to connect to task planning service.';
      if (e.toString().contains('Operation not permitted')) {
        errorMessage +=
            ' This may be due to macOS network permissions. Try running the app with network access enabled.';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage +=
            ' Make sure your API server is running on http://127.0.0.1:8000';
      }

      final taskMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.model,
        text: errorMessage,
        timestamp: DateTime.now(),
      );

      final projectIndex = _projects.indexWhere(
        (p) => p.id == _activeProjectId,
      );
      if (projectIndex != -1) {
        final updatedProject = _projects[projectIndex].copyWith(
          messages: [..._projects[projectIndex].messages, taskMessage],
        );
        _projects[projectIndex] = updatedProject;
        await _saveProjects();
        notifyListeners();
      }
    }
    debugPrint('Task API call completed');
  }

  Future<void> _saveProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final projectsJson = jsonEncode(_projects.map((p) => p.toJson()).toList());
    await prefs.setString('daycrafter_projects', projectsJson);
  }
}
