import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'models.dart';
import 'database/objectbox_service.dart';
import 'database/objectbox_entities.dart';
import 'services/embedding_service.dart';
import 'services/task_scheduler.dart';

/// Calendar view types
enum CalendarViewType { day, week, month }

/// Theme modes
enum AppThemeMode { light, dark, system }

/// Supported locales
enum AppLocale { english, chinese }

class DayCrafterProvider with ChangeNotifier {
  String? _userName;
  List<Project> _projects = [];
  String? _activeProjectId;
  bool _isLoading = false;

  // Calendar state
  bool _isCalendarActive = false;
  CalendarViewType _currentCalendarView = CalendarViewType.day;
  DateTime _selectedDate = DateTime.now();

  // Theme and localization state
  AppThemeMode _themeMode = AppThemeMode.light;
  AppLocale _locale = AppLocale.english;

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

  // Theme and locale getters
  AppThemeMode get themeMode => _themeMode;
  AppLocale get locale => _locale;
  bool get isDarkMode => _themeMode == AppThemeMode.dark;
  Locale get flutterLocale => _locale == AppLocale.chinese
      ? const Locale('zh', 'TW')
      : const Locale('en', 'US');

  void setThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void setLocale(AppLocale locale) {
    _locale = locale;
    _saveSettings();
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == AppThemeMode.light
        ? AppThemeMode.dark
        : AppThemeMode.light;
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_mode', _themeMode.name);
    prefs.setString('locale', _locale.name);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme_mode');
    final localeStr = prefs.getString('locale');

    if (themeStr != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => AppThemeMode.light,
      );
    }
    if (localeStr != null) {
      _locale = AppLocale.values.firstWhere(
        (e) => e.name == localeStr,
        orElse: () => AppLocale.english,
      );
    }
  }

  String? get userName => _userName;
  List<Project> get projects => _projects;
  String? get activeProjectId => _activeProjectId;
  bool get isLoading => _isLoading;

  // Calendar getters
  bool get isCalendarActive => _isCalendarActive;
  CalendarViewType get currentCalendarView => _currentCalendarView;
  DateTime get selectedDate => _selectedDate;

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
    // Wipe data on startup as requested
    ObjectBoxService.instance.clearAllData();

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

    // Load theme and locale settings
    await _loadSettings();

    notifyListeners();
  }

  /// Get the next available color from the palette
  String _getNextAvailableColor() {
    final usedColors = _projects
        .map((p) => p.colorHex)
        .where((c) => c != null)
        .toSet();
    return _palette.firstWhere(
      (color) => !usedColors.contains(color),
      orElse: () => _palette[0],
    );
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daycrafter_user_name', _userName!);
    notifyListeners();
  }

  Future<void> addProject(
    String name, {
    String? colorHex,
    String? emoji,
  }) async {
    // Use provided color or pick from palette
    final effectiveColor = colorHex ?? _getNextAvailableColor();

    final newProject = Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: '',
      createdAt: DateTime.now().toString(),
      colorHex: effectiveColor,
      emoji: emoji,
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
    _isCalendarActive = false; // Switch to agent view when selecting project
    notifyListeners();
  }

  // Calendar methods
  void setCalendarActive(bool active) {
    _isCalendarActive = active;
    notifyListeners();
  }

  void setCalendarView(CalendarViewType view) {
    _currentCalendarView = view;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void navigateToToday() {
    _selectedDate = DateTime.now();
    notifyListeners();
  }

  void navigatePrevious() {
    switch (_currentCalendarView) {
      case CalendarViewType.day:
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        break;
      case CalendarViewType.week:
        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
        break;
      case CalendarViewType.month:
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month - 1,
          1,
        );
        break;
    }
    notifyListeners();
  }

  void navigateNext() {
    switch (_currentCalendarView) {
      case CalendarViewType.day:
        _selectedDate = _selectedDate.add(const Duration(days: 1));
        break;
      case CalendarViewType.week:
        _selectedDate = _selectedDate.add(const Duration(days: 7));
        break;
      case CalendarViewType.month:
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          1,
        );
        break;
    }
    notifyListeners();
  }

  // ============= Calendar Task Methods =============

  /// Save tasks to calendar database
  Future<void> saveTasksToCalendar(
    List<Map<String, dynamic>> tasks, {
    String? projectId,
    String? messageId,
  }) async {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) {
      debugPrint('⚠️ ObjectBox not initialized, cannot save tasks');
      return;
    }

    try {
      final random = math.Random();
      final scheduler = TaskScheduler.instance;

      // Group entities by date for scheduling
      final entitiesByDate = <DateTime, List<CalendarTaskEntity>>{};

      for (final task in tasks) {
        // Ensure task has an ID
        if (task['id'] == null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final randomSuffix = random.nextInt(100000).toString();
          task['id'] = '$timestamp$randomSuffix';
        }

        // Use expanded to get ALL daily instances
        final taskInstances = CalendarTaskEntity.fromTaskMapExpanded(
          task,
          projectId: projectId ?? _activeProjectId,
          messageId: messageId,
        );

        // Group by date
        for (final entity in taskInstances) {
          final dateKey = DateTime(
            entity.calendarDate.year,
            entity.calendarDate.month,
            entity.calendarDate.day,
          );
          entitiesByDate.putIfAbsent(dateKey, () => []).add(entity);
        }
      }

      // Schedule tasks for each date
      final allScheduledTasks = <CalendarTaskEntity>[];
      for (final entry in entitiesByDate.entries) {
        final scheduledTasks = scheduler.scheduleTasksForDate(
          entry.key,
          entry.value,
        );
        allScheduledTasks.addAll(scheduledTasks);
      }

      db.saveCalendarTasks(allScheduledTasks);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error saving tasks to calendar: $e');
    }
  }

  /// Get tasks for a specific date
  List<Map<String, dynamic>> getTasksForDate(DateTime date) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) {
      debugPrint('⚠️ DB not initialized for getTasksForDate');
      return [];
    }

    try {
      final entities = db.getTasksForDate(date);
      return entities.map((e) => e.toTaskMap()).toList();
    } catch (e) {
      debugPrint('❌ Error getting tasks for date: $e');
      return [];
    }
  }

  /// Get tasks for a date range
  List<Map<String, dynamic>> getTasksForDateRange(
    DateTime start,
    DateTime end,
  ) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return [];

    try {
      final entities = db.getTasksForDateRange(start, end);
      return entities.map((e) => e.toTaskMap()).toList();
    } catch (e) {
      debugPrint('❌ Error getting tasks for date range: $e');
      return [];
    }
  }

  /// Toggle task completion
  void toggleTaskCompletion(String taskId) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return;

    try {
      db.toggleTaskCompletion(taskId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error toggling task completion: $e');
    }
  }

  /// Add a manually created task
  void addManualTask(Map<String, dynamic> taskData) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return;

    try {
      final entity = CalendarTaskEntity(
        uuid:
            taskData['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        taskName: taskData['task']?.toString() ?? 'Untitled',
        description: taskData['Description']?.toString(),
        calendarDate: _parseDate(taskData['dateOnCalendar']?.toString()),
        startTime: taskData['start_time']?.toString(),
        endTime: taskData['end_time']?.toString(),
        priority: taskData['priority'] is int ? taskData['priority'] : 3,
        isManuallyScheduled: taskData['isManuallyScheduled'] == true,
        projectId: _activeProjectId,
        createdAt: DateTime.now(),
      );

      db.saveCalendarTasks([entity]);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error adding manual task: $e');
    }
  }

  /// Update an existing task
  void updateTask(Map<String, dynamic> taskData) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return;

    try {
      final taskId = taskData['id']?.toString() ?? taskData['uuid']?.toString();
      if (taskId == null) return;

      final existing = db.getCalendarTaskByUuid(taskId);
      if (existing == null) return;

      // Update fields
      existing.taskName = taskData['task']?.toString() ?? existing.taskName;
      existing.description = taskData['Description']?.toString();
      existing.calendarDate = _parseDate(
        taskData['dateOnCalendar']?.toString(),
      );
      existing.startTime = taskData['start_time']?.toString();
      existing.endTime = taskData['end_time']?.toString();
      existing.priority = taskData['priority'] is int
          ? taskData['priority']
          : existing.priority;
      existing.isManuallyScheduled = taskData['isManuallyScheduled'] == true;

      db.saveCalendarTasks([existing]);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating task: $e');
    }
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
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

    // Save to ObjectBox for semantic search (in background)
    _saveMessageToObjectBox(newMessage, _activeProjectId!);

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
If this state is not initial state, then provide changes compare to previous version, and also provide some suggestions for the next steps, 
or tell the user what to look first in these task.
Do not provide anyother information. Just task summary, changes and next steps.''';
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

  /// Computes TimeToComplete from Start (dateOnCalendar) and Due (DueDate) dates
  void _computeTimeToComplete(Map<String, dynamic> task) {
    try {
      final startDateStr = task['dateOnCalendar'] as String?;
      final dueDateStr = task['DueDate'] as String?;

      if (startDateStr != null &&
          startDateStr.isNotEmpty &&
          dueDateStr != null &&
          dueDateStr.isNotEmpty) {
        final startDate = DateTime.parse(startDateStr);
        final dueDate = DateTime.parse(dueDateStr);
        final difference = dueDate.difference(startDate).inDays;

        // Ensure at least 1 day
        task['TimeToComplete'] = difference > 0 ? difference : 1;
      } else {
        // Default to 1 day if dates are missing
        task['TimeToComplete'] = task['TimeToComplete'] ?? 1;
      }
    } catch (e) {
      debugPrint('Error computing time to complete: $e');
      task['TimeToComplete'] = task['TimeToComplete'] ?? 1;
    }
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

          // Compute TimeToComplete from Start and Due dates for each task
          for (final task in taskList) {
            _computeTimeToComplete(task);
          }

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
      if (p == 1) {
        high++;
      } else if (p == 2) {
        medium++;
      } else {
        low++;
      }
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

    // CRM-style cascade delete: removes tasks from calendar DB
    ObjectBoxService.instance.deleteCalendarTasksForProject(projectId);

    // Switch to another project if deleted the active one
    if (_activeProjectId == projectId) {
      _activeProjectId = _projects.isNotEmpty ? _projects.first.id : null;
    }

    await _saveProjects();
    notifyListeners();
  }

  /// Updates a specific task within a message's task list
  /// This is used when users edit task dates from the sidebar
  Future<void> updateTaskInMessage(
    String messageId,
    Map<String, dynamic> updatedTask,
  ) async {
    if (_activeProjectId == null) return;

    final projectIndex = _projects.indexWhere((p) => p.id == _activeProjectId);
    if (projectIndex == -1) return;

    final project = _projects[projectIndex];
    final messageIndex = project.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    final message = project.messages[messageIndex];
    if (message.tasks == null) return;

    // Find and update the task by matching task name
    final taskIndex = message.tasks!.indexWhere(
      (t) => t['task'] == updatedTask['task'],
    );
    if (taskIndex == -1) return;

    // Create updated task list
    final updatedTasks = List<Map<String, dynamic>>.from(message.tasks!);
    updatedTasks[taskIndex] = updatedTask;

    // Create updated message
    final updatedMessage = Message(
      id: message.id,
      role: message.role,
      text: message.text,
      timestamp: message.timestamp,
      tasks: updatedTasks,
    );

    // Create updated messages list
    final updatedMessages = List<Message>.from(project.messages);
    updatedMessages[messageIndex] = updatedMessage;

    // Update project
    _projects[projectIndex] = project.copyWith(messages: updatedMessages);
    await _saveProjects();
    notifyListeners();
  }

  /// Transcribes an audio file to text using OpenAI Whisper API
  Future<String?> transcribeAudio(String filePath) async {
    debugPrint('Starting audio transcription for: $filePath');

    try {
      // Load API key from .env file
      String apiKey;
      try {
        if (!dotenv.isInitialized) {
          await dotenv.load(fileName: ".env");
        }
        apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
        if (apiKey.isEmpty) {
          debugPrint('OpenAI API key not found in .env file');
          return null;
        }
      } catch (e) {
        debugPrint('Dotenv error: $e');
        return null;
      }

      // Create multipart request for Whisper API
      final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', uri);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $apiKey';

      // Add the audio file
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('Audio file does not exist: $filePath');
        return null;
      }

      // Determine MIME type based on file extension
      final extension = filePath.split('.').last.toLowerCase();
      String mimeType = 'audio/mpeg'; // default
      switch (extension) {
        case 'wav':
          mimeType = 'audio/wav';
          break;
        case 'mp3':
          mimeType = 'audio/mpeg';
          break;
        case 'm4a':
          mimeType = 'audio/mp4';
          break;
        case 'ogg':
          mimeType = 'audio/ogg';
          break;
        case 'flac':
          mimeType = 'audio/flac';
          break;
        case 'aac':
          mimeType = 'audio/aac';
          break;
        case 'wma':
          mimeType = 'audio/x-ms-wma';
          break;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Add model parameter
      request.fields['model'] = 'whisper-1';

      // Send request
      debugPrint('Sending transcription request to OpenAI...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcribedText = data['text'] as String?;
        debugPrint(
          'Transcription successful: ${transcribedText?.substring(0, transcribedText.length > 50 ? 50 : transcribedText.length)}...',
        );
        return transcribedText;
      } else {
        debugPrint(
          'Transcription failed with status ${response.statusCode}: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Transcription error: $e');
      return null;
    }
  }

  /// Perform semantic search across all messages
  /// Returns messages sorted by relevance to the query
  Future<List<Message>> semanticSearch(String query, {int limit = 10}) async {
    try {
      final dbService = ObjectBoxService.instance;
      final embeddingService = EmbeddingService.instance;

      // Check if services are ready
      if (!dbService.isInitialized) {
        debugPrint('ObjectBox not initialized, skipping semantic search');
        return [];
      }

      if (!embeddingService.isReady) {
        debugPrint('Embedding service not ready, skipping semantic search');
        return [];
      }

      // Generate embedding for the query
      final queryEmbedding = await embeddingService.generateEmbedding(query);

      // Use ObjectBox to find similar messages
      final results = dbService.semanticSearchWithScores(
        queryEmbedding,
        limit: limit,
      );

      // Convert to domain models and filter by relevance threshold
      return results
          .where((r) => r.score > 0.5) // Only include relevant results
          .map((r) => r.message.toMessage())
          .toList();
    } catch (e) {
      debugPrint('Semantic search error: $e');
      return [];
    }
  }

  /// Search calendar tasks by text with optional date range filter
  /// Returns matching tasks as maps
  List<Map<String, dynamic>> searchTasks(
    String query, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      final dbService = ObjectBoxService.instance;

      if (!dbService.isInitialized) {
        return [];
      }

      final results = dbService.searchTasksByText(
        query,
        startDate: startDate,
        endDate: endDate,
      );

      return results.map((e) => e.toTaskMap()).toList();
    } catch (e) {
      debugPrint('Task search error: $e');
      return [];
    }
  }

  /// Save message to ObjectBox with embedding for future semantic search
  Future<void> _saveMessageToObjectBox(
    Message message,
    String projectId,
  ) async {
    try {
      final dbService = ObjectBoxService.instance;

      // Skip if ObjectBox isn't available
      if (!dbService.isInitialized) return;

      final embeddingService = EmbeddingService.instance;

      // Get or create project entity
      var projectEntity = dbService.getProjectByUuid(projectId);
      if (projectEntity == null) {
        final project = _projects.firstWhere(
          (p) => p.id == projectId,
          orElse: () => throw Exception('Project not found'),
        );
        projectEntity = await dbService.saveProjectFromDomain(project);
      }

      // Generate embedding if service is ready
      List<double>? embedding;
      if (embeddingService.isReady) {
        try {
          embedding = await embeddingService.generateEmbedding(message.text);
        } catch (e) {
          debugPrint('Failed to generate embedding: $e');
        }
      }

      // Save message with embedding
      await dbService.saveMessageFromDomain(
        message,
        projectEntity,
        embedding: embedding,
      );
    } catch (e) {
      debugPrint('Failed to save message to ObjectBox: $e');
    }
  }
}
