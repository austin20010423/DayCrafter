import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models.dart';

class DayCrafterProvider with ChangeNotifier {
  String? _userName;
  List<Project> _projects = [];
  String? _activeProjectId;
  bool _isLoading = false;

  // Token-efficient task changelog per project (stores compact summary instead of full JSON)
  // Format: "v1: Created 5 tasks (2 high, 2 med, 1 low) | v2: Adjusted due dates | v3: Added 2 tasks"
  Map<String, String> _taskChangelogs = {};

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

    // Load changelogs for token-efficient LLM context
    await _loadChangelogs();

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

      // Get tasks first, then pass them to GPT for summarization
      final tasks = await _getTasks(text);
      await _getAiResponse(text, tasks: tasks);

      // Reset loading after all API calls complete
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _getAiResponse(
    String userText, {
    List<Map<String, dynamic>>? tasks,
  }) async {
    debugPrint('Starting AI response...');

    try {
      // Load API key from .env file (with fallback if dotenv not loaded)
      String apiKey;
      try {
        if (!dotenv.isInitialized) {
          await dotenv.load(fileName: ".env");
        }
        apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_OPENAI_API_KEY';
      } catch (e) {
        debugPrint(
          'Dotenv error: $e - check that .env file exists in project root',
        );
        apiKey = 'YOUR_OPENAI_API_KEY';
      }

      final openAI = OpenAI.instance.build(
        token: apiKey,
        baseOption: HttpSetup(
          receiveTimeout: const Duration(seconds: 30),
          connectTimeout: const Duration(seconds: 30),
        ),
      );

      // Build the prompt based on whether we have tasks to summarize
      String userMessage = userText;
      if (tasks != null && tasks.isNotEmpty) {
        final tasksJson = jsonEncode(tasks);
        userMessage =
            '''The user requested: "$userText"

I have created the following tasks for this request:
$tasksJson

Please provide a brief, helpful summary of what did the result 
changes compare to previous version, and also provide some suggestions for the next steps, 
or tell the user what to look first in these task.''';
      }

      // Get token-efficient changelog instead of full JSON history
      final projectId = _activeProjectId ?? '';
      final changelog = _taskChangelogs[projectId] ?? '';

      // Include changelog in the system prompt (much smaller than full JSON)
      String systemPrompt =
          'You are a professional Project Manager assistant for the project "${activeProject?.name}". Help with planning, task breakdown, and research. Keep responses structured and professional.';

      if (changelog.isNotEmpty) {
        systemPrompt +=
            '\n\nTask history (compact changelog): $changelog\n\nUse this to understand what has been planned and changes made.';
      }

      final request = ChatCompleteText(
        model: GptTurboChatModel(),
        messages: [
          {"role": "system", "content": systemPrompt},
          {"role": "user", "content": userMessage},
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

  Future<List<Map<String, dynamic>>?> _getTasks(String userText) async {
    debugPrint('Starting task API call...');
    try {
      // Collect task history from previous messages
      final List<List<Map<String, dynamic>>> taskHistory = [];
      final projectMessages = activeProject?.messages ?? [];
      for (final msg in projectMessages) {
        if (msg.tasks != null && msg.tasks!.isNotEmpty) {
          taskHistory.add(msg.tasks!);
        }
      }

      final url = Uri.parse('http://127.0.0.1:8000/run');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input_task': userText,
          'task_history': taskHistory, // Include JSON state history
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final resultString = data['result'] as String;
          final tasks = jsonDecode(resultString) as List<dynamic>;
          final taskList = tasks.map((t) => t as Map<String, dynamic>).toList();

          // Create message with task cards (GPT will provide the summary separately)
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

            // Update token-efficient changelog
            _updateTaskChangelog(_activeProjectId!, taskList);

            notifyListeners();
          }

          debugPrint('Task API call completed');
          return taskList;
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
    return null;
  }

  Future<void> _saveProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final projectsJson = jsonEncode(_projects.map((p) => p.toJson()).toList());
    await prefs.setString('daycrafter_projects', projectsJson);
  }

  /// Updates the token-efficient changelog with a compact summary of new tasks
  void _updateTaskChangelog(
    String projectId,
    List<Map<String, dynamic>> tasks,
  ) {
    // Count priorities
    int high = 0, medium = 0, low = 0;
    for (final task in tasks) {
      final p = task['priority'] is int
          ? task['priority']
          : int.tryParse(task['priority']?.toString() ?? '3') ?? 3;
      if (p == 1)
        high++;
      else if (p == 2)
        medium++;
      else
        low++;
    }

    // Get existing changelog
    final existing = _taskChangelogs[projectId] ?? '';

    // Count versions
    final versionCount =
        existing.split('|').where((s) => s.trim().isNotEmpty).length + 1;

    // Create compact entry like "v1: 5 tasks (2H/2M/1L)"
    final entry =
        'v$versionCount: ${tasks.length} tasks (${high}H/${medium}M/${low}L)';

    // Append to changelog (limit to last 10 versions for token efficiency)
    if (existing.isEmpty) {
      _taskChangelogs[projectId] = entry;
    } else {
      final parts = existing.split(' | ');
      if (parts.length >= 10) {
        parts.removeAt(0); // Remove oldest
      }
      parts.add(entry);
      _taskChangelogs[projectId] = parts.join(' | ');
    }

    // Save to SharedPreferences
    _saveChangelogs();
  }

  Future<void> _saveChangelogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daycrafter_changelogs', jsonEncode(_taskChangelogs));
  }

  Future<void> _loadChangelogs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('daycrafter_changelogs');
    if (data != null) {
      _taskChangelogs = Map<String, String>.from(jsonDecode(data));
    }
  }

  /// Deletes a project and cleans up its changelog
  Future<void> deleteProject(String projectId) async {
    _projects.removeWhere((p) => p.id == projectId);

    // Clean up changelog for this project
    _taskChangelogs.remove(projectId);
    await _saveChangelogs();

    // Switch to another project if deleted the active one
    if (_activeProjectId == projectId) {
      _activeProjectId = _projects.isNotEmpty ? _projects.first.id : null;
    }

    await _saveProjects();
    notifyListeners();
  }
}
