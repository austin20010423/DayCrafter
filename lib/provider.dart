import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models.dart';
import 'database/objectbox_service.dart';
import 'database/objectbox_entities.dart';
import 'services/embedding_service.dart';
import 'services/task_scheduler.dart';
import 'services/local_auth_service.dart';
import 'services/short_term_memory.dart';
import 'services/global_agent_tools.dart';
import 'config/tools_config.dart';

// ============================================================================
/// Calendar view types
enum CalendarViewType { day, week, month }

/// Theme modes
enum AppThemeMode { light, dark, system }

/// Supported locales
enum AppLocale { english, chinese }

/// Navigation items in sidebar
enum NavItem { calendar, agent, settings, projectChat }

class DayCrafterProvider with ChangeNotifier {
  // Auth state
  final LocalAuthService _authService = LocalAuthService();
  bool _isLoggedIn = false;
  bool _isCheckingAuth = true; // Start as true to show loading initially
  String? _currentUserEmail;

  String? _userName;
  List<Project> _projects = [];
  String? _activeProjectId;
  bool _isLoading = false;

  // Global Agent state
  final List<Message> _globalMessages = [];
  String _briefingLocation = 'Ready';
  String _briefingWeather = 'Ready';
  String _briefingWeatherDetail = '';
  String _nextEventInfo = 'No upcoming events';
  late ShortTermMemory _globalShortTermMemory;

  int _requestCounter = 0;
  int? _currentRequestId;
  final Set<int> _cancelledRequests = {};

  // API availability state (for fallback to pure chat mode)
  // API availability state (for fallback to pure chat mode)
  bool _isApiAvailable = true;

  // MCP Client Integration
  McpClient? _mcpClient;
  McpClient? get mcpClient => _mcpClient;
  Process? _mcpProcess;

  // Navigation state
  NavItem _activeNavItem = NavItem.agent;

  // Calendar state
  CalendarViewType _currentCalendarView = CalendarViewType.day;
  DateTime _selectedDate = DateTime.now();

  // Overlay coordination
  int _overlayCloseSignal = 0;
  int get overlayCloseSignal => _overlayCloseSignal;

  void closeAllOverlays() {
    _overlayCloseSignal++;
    notifyListeners();
  }

  // Theme and localization state
  AppThemeMode _themeMode = AppThemeMode.light;
  AppLocale _locale = AppLocale.english;

  // LangChain short-term memory for token-efficient conversation context
  late ShortTermMemory _shortTermMemory;

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

  // Auth getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isCheckingAuth => _isCheckingAuth;
  String? get currentUserEmail => _currentUserEmail;

  String? get userName => _userName;
  List<Project> get projects => _projects;
  String? get activeProjectId => _activeProjectId;
  bool get isLoading => _isLoading;

  // Navigation getters
  NavItem get activeNavItem => _activeNavItem;
  bool get isCalendarActive => _activeNavItem == NavItem.calendar;
  bool get isSettingsActive => _activeNavItem == NavItem.settings;
  bool get isProjectChatActive => _activeNavItem == NavItem.projectChat;
  bool get isGlobalAgentActive => _activeNavItem == NavItem.agent;

  // Calendar getters
  CalendarViewType get currentCalendarView => _currentCalendarView;
  DateTime get selectedDate => _selectedDate;

  void setActiveNavItem(NavItem item) {
    _activeNavItem = item;
    notifyListeners();
  }

  Project? get activeProject {
    if (_activeProjectId == null) return null;
    return _projects.firstWhere(
      (p) => p.id == _activeProjectId,
      orElse: () => _projects.first,
    );
  }

  // Global Agent Getters
  List<Message> get globalMessages => _globalMessages;
  String get briefingLocation => _briefingLocation;
  String get briefingWeather => _briefingWeather;
  String get briefingWeatherDetail => _briefingWeatherDetail;
  String get nextEventInfo => _nextEventInfo;

  // Memory getters
  ShortTermMemory get shortTermMemory => _shortTermMemory;
  String get memoryContext => _shortTermMemory.getLastNMessagesContext(5);
  int get estimatedMemoryTokens => _shortTermMemory.getEstimatedTokens();

  DayCrafterProvider() {
    _shortTermMemory = ShortTermMemory(maxMessages: 10, maxTokens: 4000);
    _globalShortTermMemory = ShortTermMemory(maxMessages: 10, maxTokens: 4000);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load theme and locale settings (available before login)
    await _loadSettings();
    notifyListeners();
  }

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  void setRecording(bool value) {
    _isRecording = value;
    notifyListeners();
  }

  Future<void> sendAudioMessage(String filePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) {
        throw Exception('OpenAI API Key not found');
      }

      final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = 'whisper-1'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        final transcript = data['text'] as String;

        // Send transcribed text as a message
        await sendMessage(
          transcript,
          MessageRole.user,
          attachments: [
            {'type': 'audio', 'path': filePath},
          ],
        );
      } else {
        throw Exception('Transcription failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending audio message: $e');
      // Show error message in chat if transcription fails
      if (_activeProjectId != null) {
        await sendMessage(
          "I couldn't transcribe the audio. Error: $e",
          MessageRole.model,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  // ============ Authentication Methods ============

  /// Check if user is logged in on app start
  Future<void> checkAuthStatus() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      _isLoggedIn = true;
      _currentUserEmail = user['email'];
      _userName = user['name'];

      // Reset to default page (Agent)
      _activeNavItem = NavItem.agent;

      // Load user-specific data
      await _loadUserData();
    }

    // Done checking auth
    _isCheckingAuth = false;
    notifyListeners();
  }

  /// Register a new account
  Future<String?> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final error = await _authService.register(
      email: email,
      password: password,
      name: name,
    );

    if (error == null) {
      // Auto-login after successful registration
      await login(email: email, password: password);
    }

    return error;
  }

  /// Request password reset code
  Future<String?> requestPasswordResetCode(String email) async {
    return _authService.generateVerificationCode(email);
  }

  /// Reset password
  Future<bool> confirmPasswordReset(String email, String newPassword) async {
    return _authService.resetPassword(email, newPassword);
  }

  /// Login with email and password
  Future<bool> login({required String email, required String password}) async {
    final user = await _authService.login(email: email, password: password);

    if (user != null) {
      _isLoggedIn = true;
      _currentUserEmail = user['email'];
      _userName = user['name'];

      // Reset to default page (Agent)
      _activeNavItem = NavItem.agent;

      // Load user-specific data
      await _loadUserData();

      notifyListeners();
      return true;
    }

    return false;
  }

  /// Logout current user
  Future<void> logout() async {
    await _authService.logout();
    _isLoggedIn = false;
    _currentUserEmail = null;
    _userName = null;
    _projects = [];
    _activeProjectId = null;

    _shortTermMemory.clear(); // Clear memory on logout
    _globalShortTermMemory.clear(); // Clear global memory on logout
    notifyListeners();
  }

  /// Get list of registered accounts for account selector
  Future<List<Map<String, String>>> getRegisteredAccounts() async {
    return _authService.getRegisteredAccounts();
  }

  /// Delete a registered account
  Future<void> deleteAccount(String email) async {
    await _authService.deleteAccount(email);
    notifyListeners();
  }

  /// Load user-specific data after login
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userPrefix = _currentUserEmail ?? '';

    // Load projects for this user
    // Load projects for this user
    // 1. Try ObjectBox first
    final db = ObjectBoxService.instance;
    if (db.isInitialized) {
      final entities = db.getAllProjects(userEmail: _currentUserEmail);
      if (entities.isNotEmpty) {
        _projects = entities.map((e) => e.toProject()).toList();
      }
    }

    // 2. Fallback to SharedPreferences if empty
    if (_projects.isEmpty) {
      final projectsJson = prefs.getString('${userPrefix}_projects');
      if (projectsJson != null) {
        final List<dynamic> decoded = jsonDecode(projectsJson);
        _projects = decoded.map((p) => Project.fromJson(p)).toList();

        // Sync to ObjectBox for future
        await _saveProjects();
      }
    }

    // Load memory for the first project if any exist
    if (_projects.isNotEmpty) {
      _activeProjectId = _projects.first.id;
      _loadMemoryForProject(_activeProjectId!);
    }

    // Load settings
    await _loadSettings();
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daycrafter_user_name', _userName!);

    // Also update in auth service
    await _authService.updateUserName(name.trim());

    notifyListeners();
  }

  Future<String> addProject(
    String name, {
    String? description,
    String? colorHex,
    String? icon,
  }) async {
    // Use provided color or pick from palette
    final effectiveColor = colorHex ?? _getNextAvailableColor();

    // Save current project's memory before creating a new project
    if (_activeProjectId != null) {
      _saveMemoryForProject(_activeProjectId!);
    }

    final newProject = Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description ?? '',
      createdAt: DateTime.now().toIso8601String(),
      colorHex: effectiveColor,
      icon: icon,
      messages: [],
    );
    _projects.add(newProject);
    _activeProjectId = newProject.id;

    // Clear memory for the new project (fresh start)
    _shortTermMemory.clear();

    await _saveProjects();
    notifyListeners();
    return newProject.id;
  }

  void setActiveProject(String? id) {
    // Save current memory before switching
    if (_activeProjectId != null) {
      _saveMemoryForProject(_activeProjectId!);
    }

    _activeProjectId = id;
    _activeNavItem = NavItem
        .projectChat; // Switch to project chat view when selecting project

    // Load memory for new project
    if (id != null) {
      _loadMemoryForProject(id);
    } else {
      _shortTermMemory.clear();
    }

    notifyListeners();
  }

  /// Save short-term memory for a project
  void _saveMemoryForProject(String projectId) {
    try {
      final prefs = SharedPreferences.getInstance();
      prefs.then((p) {
        final memoryJson = _shortTermMemory.exportToJson();
        final userPrefix = _currentUserEmail != null
            ? '${_currentUserEmail}_memory'
            : 'daycrafter_memory';
        p.setString('${userPrefix}_$projectId', memoryJson);
      });
    } catch (e) {
      debugPrint('Error saving memory for project: $e');
    }
  }

  /// Load short-term memory for a project
  void _loadMemoryForProject(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPrefix = _currentUserEmail != null
          ? '${_currentUserEmail}_memory'
          : 'daycrafter_memory';
      final memoryJson = prefs.getString('${userPrefix}_$projectId');

      _shortTermMemory.clear();
      if (memoryJson != null) {
        _shortTermMemory.importFromJson(memoryJson);
      }
    } catch (e) {
      debugPrint('Error loading memory for project: $e');
      _shortTermMemory.clear();
    }
  }

  // ... inside DayCrafterProvider ...
  Future<void> _deleteProjectMemory(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPrefix = _currentUserEmail != null
          ? '${_currentUserEmail}_memory'
          : 'daycrafter_memory';
      await prefs.remove('${userPrefix}_$projectId');
    } catch (e) {
      debugPrint('Error deleting memory for project: $e');
    }
  }

  /// Get all project memories for Global Agent
  Future<Map<String, dynamic>> getAllProjectMemories() async {
    final prefs = await SharedPreferences.getInstance();
    final userPrefix = _currentUserEmail != null
        ? '${_currentUserEmail}_memory'
        : 'daycrafter_memory';

    final Map<String, dynamic> allMemories = {};

    for (final project in _projects) {
      final memoryJson = prefs.getString('${userPrefix}_${project.id}');
      if (memoryJson != null) {
        try {
          final memoryData = jsonDecode(memoryJson);
          allMemories[project.name] = memoryData;
        } catch (e) {
          allMemories[project.name] = "Error loading memory";
        }
      } else {
        allMemories[project.name] = "No memory yet.";
      }
    }
    return allMemories;
  }

  /// Get all upcoming calendar events for Global Agent
  Future<List<Map<String, dynamic>>> getAllUpcomingEvents({
    int limit = 50,
  }) async {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return [];

    final now = DateTime.now();
    final tasks = db
        .getAllCalendarTasks()
        .where((t) => t.calendarDate.isAfter(now))
        .toList();

    tasks.sort((a, b) => a.calendarDate.compareTo(b.calendarDate));

    return tasks.take(limit).map((t) {
      return {
        'id': t.id,
        'task': t.taskName,
        'date': t.calendarDate.toIso8601String(),
        'description': t.description,
        'status': t.isCompleted ? 'Completed' : 'Pending',
      };
    }).toList();
  }

  // Calendar methods
  void setCalendarActive(bool active) {
    _activeNavItem = active ? NavItem.calendar : NavItem.agent;
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
        final pid = projectId ?? _activeProjectId;

        final taskInstances = CalendarTaskEntity.fromTaskMapExpanded(
          task,
          projectId: pid,
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

      // Set userEmail on all tasks before saving
      for (final task in allScheduledTasks) {
        task.userEmail = _currentUserEmail;
      }

      db.saveCalendarTasks(allScheduledTasks);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error saving tasks to calendar: $e');
    }
  }

  /// Get tasks for a specific date (filtered by current user)
  List<Map<String, dynamic>> getTasksForDate(DateTime date) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) {
      debugPrint('⚠️ DB not initialized for getTasksForDate');
      return [];
    }

    try {
      final entities = db.getTasksForDate(date, userEmail: _currentUserEmail);
      return entities.map((e) => e.toTaskMap()).toList();
    } catch (e) {
      debugPrint('❌ Error getting tasks for date: $e');
      return [];
    }
  }

  /// Get tasks for a date range (filtered by current user)
  List<Map<String, dynamic>> getTasksForDateRange(
    DateTime start,
    DateTime end,
  ) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return [];

    try {
      final entities = db.getTasksForDateRange(
        start,
        end,
        userEmail: _currentUserEmail,
      );
      return entities.map((e) => e.toTaskMap()).toList();
    } catch (e) {
      debugPrint('❌ Error getting tasks for date range: $e');
      return [];
    }
  }

  /// Get all tasks for a specific project
  List<Map<String, dynamic>> getTasksForProject(String projectId) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return [];

    try {
      final entities = db.getTasksForProject(projectId);
      return entities.map((e) => e.toTaskMap()).toList();
    } catch (e) {
      debugPrint('❌ Error getting tasks for project: $e');
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
        projectId: taskData['projectId']?.toString() ?? _activeProjectId,
        createdAt: DateTime.now(),
        userEmail: _currentUserEmail,
      );

      db.saveCalendarTasks([entity]);

      if (entity.projectId != null) {
        final description = entity.description != null
            ? ' - ${entity.description}'
            : '';
        final timeSuffix = entity.startTime != null
            ? ' at ${entity.startTime}'
            : '';
        _recordTaskInProjectMemory(
          entity.projectId!,
          'User manually created a task: "${entity.taskName}"$description scheduled for ${entity.calendarDate.toIso8601String().split('T')[0]}$timeSuffix',
        );
      }

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
      // Fix: Prioritize UUID if available, as 'id' might be the originalTaskId grouping ID
      final taskId = taskData['uuid']?.toString() ?? taskData['id']?.toString();
      if (taskId == null) return;

      final existing = db.getCalendarTaskByUuid(taskId);
      if (existing == null) return;

      // Update fields
      existing.taskName = taskData['task']?.toString() ?? existing.taskName;
      existing.description =
          taskData['Description']?.toString() ?? existing.description;
      if (taskData['dateOnCalendar'] != null) {
        existing.calendarDate = _parseDate(
          taskData['dateOnCalendar'].toString(),
        );
      }
      existing.startTime =
          taskData['start_time']?.toString() ?? existing.startTime;
      existing.endTime = taskData['end_time']?.toString() ?? existing.endTime;
      existing.priority = taskData['priority'] is int
          ? taskData['priority']
          : existing.priority;
      existing.isManuallyScheduled =
          taskData['isManuallyScheduled'] == true ||
          existing.isManuallyScheduled;
      existing.projectId =
          taskData['projectId']?.toString() ?? existing.projectId;
      existing.userEmail = _currentUserEmail;

      db.saveCalendarTasks([existing]);

      if (existing.projectId != null) {
        _recordTaskInProjectMemory(
          existing.projectId!,
          'User updated a task: "${existing.taskName}" (Scheduled: ${existing.calendarDate.toIso8601String().split('T')[0]})',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating task: $e');
    }
  }

  /// Delete a task by ID
  void deleteTask(String taskId) {
    final db = ObjectBoxService.instance;
    if (!db.isInitialized) return;

    try {
      final task = db.getCalendarTaskByUuid(taskId);
      if (task == null) return;

      final taskName = task.taskName;
      final projectId = task.projectId;

      db.deleteCalendarTaskByUuid(taskId);

      // Record deletion in project memory
      if (projectId != null) {
        _recordTaskInProjectMemory(
          projectId,
          'User deleted a task: "$taskName"',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error deleting task: $e');
    }
  }

  /// Record a task-related action in the project's semantic memory
  void _recordTaskInProjectMemory(String projectId, String logMessage) {
    if (projectId.isEmpty) return;

    final newMessage = Message(
      id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.model, // Recorded as model behavior/system trace
      text: '[System Memory Log] $logMessage',
      timestamp: DateTime.now(),
    );

    // 1. Add to ObjectBox for semantic search
    _saveMessageToObjectBox(newMessage, projectId);

    // 2. Add to LangChain short-term memory if it's the active project
    if (_activeProjectId == projectId) {
      _shortTermMemory.addMessageWithId(
        newMessage.id,
        newMessage.text,
        'assistant',
      );
      _saveMemoryForProject(projectId);
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

  Future<void> sendMessage(
    String text,
    MessageRole role, {
    List<Map<String, String>>? attachments,
    List<Map<String, dynamic>>? tasks,
    bool isMcpConsent = false,
    String? mcpInputPending,
  }) async {
    if (_activeProjectId == null) return;

    final projectIndex = _projects.indexWhere((p) => p.id == _activeProjectId);
    if (projectIndex == -1) return;

    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: role,
      text: text,
      attachments: attachments,
      tasks: tasks,
      isMcpConsent: isMcpConsent,
      mcpInputPending: mcpInputPending,
      timestamp: DateTime.now(),
    );

    final updatedProject = _projects[projectIndex].copyWith(
      messages: [..._projects[projectIndex].messages, newMessage],
    );

    _projects[projectIndex] = updatedProject;
    await _saveProjects();

    // Add to LangChain short-term memory (token-efficient)
    String memoryText = text;
    if (tasks != null && tasks.isNotEmpty) {
      final taskSummary = tasks
          .map((t) => "- ${t['task']} (Due: ${t['DueDate']})")
          .join('\n');
      memoryText +=
          "\n[System: The following tasks were created and displayed to the user:]\n$taskSummary";
    }

    _shortTermMemory.addMessageWithId(
      newMessage.id,
      memoryText,
      role == MessageRole.user ? 'user' : 'assistant',
    );

    // Save memory for this project after each message
    _saveMemoryForProject(_activeProjectId!);

    // Save to ObjectBox for semantic search (in background)
    _saveMessageToObjectBox(newMessage, _activeProjectId!);

    notifyListeners();

    if (role == MessageRole.user) {
      // Set loading BEFORE making API calls so animation appears immediately
      _isLoading = true;
      // create a request id so callers can cancel this particular call
      _currentRequestId = ++_requestCounter;
      final int requestId = _currentRequestId!;
      notifyListeners();

      // Always call GPT - it decides if it needs the MCP tool (task_and_schedule_planer)
      await _getAiResponse(
        text,
        attachments: attachments,
        requestId: requestId,
      );

      // If this request was cancelled, don't overwrite loading state again
      if (!_cancelledRequests.contains(requestId)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// User approved the pending MCP action
  Future<void> approvePendingMcp(Message message) async {
    if (message.mcpInputPending == null) return;

    // Set loading
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Update message in project to remove consent buttons immediately
      if (_activeProjectId != null) {
        final projectIndex = _projects.indexWhere(
          (p) => p.id == _activeProjectId,
        );
        if (projectIndex != -1) {
          final project = _projects[projectIndex];
          final msgIndex = project.messages.indexWhere(
            (m) => m.id == message.id,
          );
          if (msgIndex != -1) {
            final updatedMsg = project.messages[msgIndex].copyWith(
              isMcpConsent: false,
              setMcpInputPendingToNull: true,
            );
            // Create mutable copy of messages list
            final newMessages = List<Message>.from(project.messages);
            newMessages[msgIndex] = updatedMsg;

            _projects[projectIndex] = project.copyWith(messages: newMessages);
            await _saveProjects();
            notifyListeners(); // Force UI rebuild to hide buttons
          }
        }
      }
      final mcpInput = message.mcpInputPending!;

      // Call the MCP server
      final tasks = await _getTasks(mcpInput);

      if (tasks != null && tasks.isNotEmpty) {
        // Context for summary was removed.

        // Generate summary (stubbed for now, using a generic message is safer than complex logic duplication)
        // Ideally we call OpenAi, but for now let's just confirm.
        // Actually, we can just say:

        // Generate summary (stubbed for now, using a generic message is safer than complex logic duplication)
        // Ideally we call OpenAi, but for now let's just confirm.
        // Actually, we can just say:
        final summaryText =
            "I've scheduled the tasks based on your request. You can check the cards below.";

        await sendMessage(summaryText, MessageRole.model, tasks: tasks);
      } else {
        await sendMessage(
          "The tool executed but returned no tasks.",
          MessageRole.model,
        );
      }
    } catch (e) {
      debugPrint("Error executing approved MCP: $e");
      await sendMessage(
        "Sorry, I encountered an error executing the plan.",
        MessageRole.model,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// User denied the pending MCP action
  Future<void> denyPendingMcp(Message message) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Update message in project to remove consent buttons immediately
      if (_activeProjectId != null) {
        final projectIndex = _projects.indexWhere(
          (p) => p.id == _activeProjectId,
        );
        if (projectIndex != -1) {
          final project = _projects[projectIndex];
          final msgIndex = project.messages.indexWhere(
            (m) => m.id == message.id,
          );
          if (msgIndex != -1) {
            final updatedMsg = project.messages[msgIndex].copyWith(
              isMcpConsent: false,
              setMcpInputPendingToNull: true,
            );
            // Create mutable copy of messages list
            final newMessages = List<Message>.from(project.messages);
            newMessages[msgIndex] = updatedMsg;

            _projects[projectIndex] = project.copyWith(messages: newMessages);
            await _saveProjects();
            notifyListeners(); // Force UI rebuild to hide buttons
          }
        }
      }
      await sendMessage(
        "Okay, I won't use the scheduler tool. I've noted your request in our conversation history.",
        MessageRole.model,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _getAiResponse(
    String userText, {
    List<Map<String, String>>? attachments,
    required int requestId,
  }) async {
    try {
      // Build user message with attachments
      String userMessage = userText;
      if (attachments != null && attachments.isNotEmpty) {
        for (final att in attachments) {
          if (_cancelledRequests.contains(requestId)) {
            return;
          }
          final type = att['type'];
          final name = att['name'] ?? 'attachment';
          final path = att['path'];
          if (type == 'text' && path != null) {
            try {
              final file = File(path);
              if (await file.exists()) {
                final content = await file.readAsString();
                userMessage += '\n\n[Attached file: $name]\n$content';
              } else {
                userMessage += '\n\n[Attached file: $name]';
              }
            } catch (e) {
              debugPrint('Error reading attached text file: $e');
            }
          } else if ((type == 'voice' || type == 'audio') && path != null) {
            try {
              final transcript = await transcribeAudio(path);
              if (transcript != null && transcript.isNotEmpty) {
                userMessage += '\n\n[Audio transcript: $name]\n$transcript';
              } else {
                userMessage += '\n\n[Audio attached: $name]';
              }
            } catch (e) {
              debugPrint('Error transcribing attached audio: $e');
            }
          } else if (type == 'recording') {
            userMessage += '\n\n[Voice recording attached: $name]';
          }
        }
      }

      // Get token-efficient changelog
      final String changelog = '';

      // Get all tasks in the project to ensure full context
      String projectContext = '';
      if (_activeProjectId != null) {
        final projectTasks = getTasksForProject(_activeProjectId!);
        if (projectTasks.isNotEmpty) {
          // Group tasks by completion status
          final pendingTasks = projectTasks
              .where((t) => t['isCompleted'] != true)
              .toList();
          final completedTasks = projectTasks
              .where((t) => t['isCompleted'] == true)
              .toList();

          projectContext = '\n\n## EXISTING TASKS IN THIS PROJECT:\n';

          if (pendingTasks.isNotEmpty) {
            projectContext += '\n### Pending Tasks (${pendingTasks.length}):\n';
            for (final task in pendingTasks.take(15)) {
              // Limit to avoid token overflow
              final taskName = task['task'] ?? 'Unnamed';
              final dueDate = task['DueDate'] ?? 'No due date';
              final priority = task['priority'] ?? 3;
              final priorityLabel = priority == 1
                  ? '🔴 High'
                  : (priority == 2 ? '🟡 Medium' : '🟢 Low');
              projectContext +=
                  '- $taskName (Due: $dueDate, Priority: $priorityLabel)\n';
            }
            if (pendingTasks.length > 15) {
              projectContext +=
                  '... and ${pendingTasks.length - 15} more pending tasks\n';
            }
          }

          if (completedTasks.isNotEmpty) {
            projectContext +=
                '\n### Completed Tasks (${completedTasks.length}):\n';
            for (final task in completedTasks.take(5)) {
              // Show fewer completed tasks
              final taskName = task['task'] ?? 'Unnamed';
              projectContext += '- ✅ $taskName\n';
            }
            if (completedTasks.length > 5) {
              projectContext +=
                  '... and ${completedTasks.length - 5} more completed tasks\n';
            }
          }
        }
      }

      // Build system prompt using LangChain short-term memory (token-efficient)
      String systemPrompt = _shortTermMemory.getSystemPrompt(
        projectName: activeProject?.name,
      );

      // Inject the full project context (tasks)
      systemPrompt += projectContext;

      // Add basic MCP context if needed, but keeping it clean as requested
      if (changelog.isNotEmpty) {
        systemPrompt += '\nTask Changelog: $changelog';
      }

      // Add instructions for native tool usage
      systemPrompt +=
          '''
You are an autonomous assistant with helping user ${_userName ?? ''} to manage their schedule. 

You have access to tools. Use them whenever appropriate to help the user.
If the user wants to schedule or plan tasks, use the "task_and_schedule_planer" tool.
Always provide sources when you search the web.
Do not talk about MCP tool to the user.
Always use same language as the user.
''';

      if (_cancelledRequests.contains(requestId)) {
        return;
      }

      // Use Responses API with web search tool - model decides when to search
      await _getResponsesApiResponse(userMessage, systemPrompt, requestId);
      return;
    } catch (e) {
      debugPrint('AI Error: $e');
      await sendMessage(
        "Failed to connect to AI service. Please check your OpenAI API key.",
        MessageRole.model,
      );
    }
  }

  /// Use the Responses API with web search capability
  /// The model will automatically decide when to search based on instructions
  Future<void> _getResponsesApiResponse(
    String userQuery,
    String systemPrompt,
    int requestId,
  ) async {
    // Ensure dotenv is loaded
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        debugPrint('Dotenv error: $e');
      }
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      await sendMessage(
        "OpenAI API key not configured. Please set OPENAI_API_KEY in your .env file.",
        MessageRole.model,
      );
      return;
    }

    // Create a placeholder message for the AI response
    final assistantMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    final assistantMessage = Message(
      id: assistantMessageId,
      role: MessageRole.model,
      text: '',
      timestamp: DateTime.now(),
    );

    // Add placeholder to project immediately
    if (_activeProjectId != null) {
      final projectIndex = _projects.indexWhere(
        (p) => p.id == _activeProjectId,
      );
      if (projectIndex != -1) {
        final updatedProject = _projects[projectIndex].copyWith(
          messages: [..._projects[projectIndex].messages, assistantMessage],
        );
        _projects[projectIndex] = updatedProject;
        notifyListeners();
      }
    }

    try {
      // Initialize MCP client early so it's ready for tool calls
      if (_mcpClient == null) {
        await _initMcpClient();
      }

      // Build conversation history as structured messages using formal item format
      final history = _shortTermMemory.getMessages();
      final List<Map<String, dynamic>> items = [];
      for (final msg in history) {
        final role = msg['role'] == 'user' ? 'user' : 'assistant';
        items.add({
          'type': 'message',
          'role': role,
          'content': [
            {
              'type': role == 'user' ? 'input_text' : 'output_text',
              'text': msg['content'] ?? '',
            },
          ],
        });
      }
      items.add({
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': userQuery},
        ],
      });

      // Combine user system prompt with basic instructions
      final instructions = '''$systemPrompt

You are a helpful AI assistant with web search and task planning capabilities. 
If a query involves current events, recent news, real-time data, or up-to-date information, use the web search tool.
If a user wants to plan, schedule, or organize tasks, use the task_and_schedule_planer tool.
Always provide sources when you search the web.''';

      // Use streaming HTTP request
      final request = http.Request(
        'POST',
        Uri.parse('https://api.openai.com/v1/responses'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });
      request.body = jsonEncode({
        'model': 'gpt-5-nano',
        'instructions': instructions,
        'input': items,
        'tools': aiTools,
        'tool_choice': 'auto',
        'reasoning': {'effort': 'low'},
        'stream': true,
      });

      final streamedResponse = await http.Client().send(request);

      if (_cancelledRequests.contains(requestId)) {
        return;
      }

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        debugPrint('API Error: $body');
        throw Exception('API error: ${streamedResponse.statusCode}');
      }

      String aiText = '';
      String responseId = '';
      final annotations = <Map<String, dynamic>>[];
      String buffer = ''; // Buffer for incomplete SSE messages

      // Track pending function calls by item_id
      final pendingFunctionCalls = <String, Map<String, dynamic>>{};

      // Flag to skip text accumulation when function call is in progress
      bool skipTextAccumulation = false;

      // Process the SSE stream with buffering
      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        if (_cancelledRequests.contains(requestId)) {
          return;
        }

        // Add chunk to buffer
        // debugPrint('📥 Chunk: $chunk'); // Uncomment for deep debugging
        buffer += chunk;

        // Process complete SSE messages (ended by double newline)
        while (buffer.contains('\n\n')) {
          final messageEnd = buffer.indexOf('\n\n');
          final message = buffer.substring(0, messageEnd);
          buffer = buffer.substring(messageEnd + 2);

          // Process each line in the message to extract and join 'data:' content
          final lines = message.split('\n');
          String eventData = '';
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              eventData +=
                  '${eventData.isEmpty ? '' : '\n'}${line.substring(6).trim()}';
            }
          }

          if (eventData.isNotEmpty && eventData != '[DONE]') {
            try {
              final event = jsonDecode(eventData);
              final type = event['type'] as String?;

              // LOG EVERYTHING FOR DEBUGGING (commented out to reduce noise)
              // debugPrint('📡 Event: $type');

              if (type == 'error' || type == 'response.error') {
                debugPrint('⚠️ ERROR EVENT: $eventData');
                final error = event['error'] as Map<String, dynamic>?;
                if (error != null) {
                  aiText += '\n\n*Error: ${error['message'] ?? 'Unknown'}*\n';
                }
              }

              if (type == 'response.created') {
                responseId = event['response']['id'];
              } else if (type == 'response.output_text.delta' ||
                  type == 'response.text.delta' ||
                  event.containsKey('delta')) {
                // Skip text accumulation if we're in a function call
                if (skipTextAccumulation) continue;

                // Comprehensive delta extraction
                var delta = '';
                if (event['delta'] != null) {
                  if (event['delta'] is String) {
                    delta = event['delta'];
                  } else if (event['delta'] is Map &&
                      event['delta']['content'] != null) {
                    delta = event['delta']['content'];
                  }
                } else if (event['text'] != null) {
                  delta = event['text'];
                }

                if (delta.isNotEmpty) {
                  aiText += delta;

                  // Progressively update UI
                  if (_activeProjectId != null) {
                    final projectIndex = _projects.indexWhere(
                      (p) => p.id == _activeProjectId,
                    );
                    if (projectIndex != -1) {
                      final currentMessages = List<Message>.from(
                        _projects[projectIndex].messages,
                      );
                      final msgIndex = currentMessages.indexWhere(
                        (m) => m.id == assistantMessageId,
                      );
                      if (msgIndex != -1) {
                        currentMessages[msgIndex] = currentMessages[msgIndex]
                            .copyWith(text: aiText);
                        _projects[projectIndex] = _projects[projectIndex]
                            .copyWith(messages: currentMessages);
                        notifyListeners();
                      }
                    }
                  }
                }
              } else if (type == 'response.output_text.annotation.added') {
                // Collect annotations for later
                final annotation = event['annotation'] as Map<String, dynamic>?;
                if (annotation != null) {
                  annotations.add(annotation);
                }
              } else if (type == 'response.output_item.added') {
                // Track function call metadata when output item is added
                final item = event['item'] as Map<String, dynamic>?;
                if (item != null && item['type'] == 'function_call') {
                  // Stop accumulating text - we're in a function call
                  skipTextAccumulation = true;

                  // Clear any text that was streamed (it's the tool arguments)
                  // and show a placeholder message
                  aiText = '*Creating your tasks...*';

                  // Update UI immediately to hide the raw JSON
                  if (_activeProjectId != null) {
                    final projectIndex = _projects.indexWhere(
                      (p) => p.id == _activeProjectId,
                    );
                    if (projectIndex != -1) {
                      final currentMessages = List<Message>.from(
                        _projects[projectIndex].messages,
                      );
                      final msgIndex = currentMessages.indexWhere(
                        (m) => m.id == assistantMessageId,
                      );
                      if (msgIndex != -1) {
                        currentMessages[msgIndex] = currentMessages[msgIndex]
                            .copyWith(text: aiText);
                        _projects[projectIndex] = _projects[projectIndex]
                            .copyWith(messages: currentMessages);
                        notifyListeners();
                      }
                    }
                  }

                  final itemId = item['id'] as String?;
                  final callId = item['call_id'] as String?;
                  final name = item['name'] as String?;
                  if (itemId != null) {
                    pendingFunctionCalls[itemId] = {
                      'name': name,
                      'call_id': callId,
                    };
                  }
                }
              } else if (type == 'response.function_call_arguments.done') {
                // Function call completed - look up tracked metadata
                final itemId = event['item_id'] as String?;
                final arguments = event['arguments'] as String?;

                // Look up the function call metadata we tracked earlier
                final fcMeta = itemId != null
                    ? pendingFunctionCalls[itemId]
                    : null;
                final name = fcMeta?['name'] as String?;
                final callId = fcMeta?['call_id'] as String?;

                if (name == 'add_calendar_task' &&
                    arguments != null &&
                    callId != null) {
                  try {
                    final args = jsonDecode(arguments);
                    final String title = args['title'] ?? 'Untitled';
                    final String? description = args['description'];
                    final String startDateTimeStr = args['start_date_time'];
                    final String? endDateTimeStr = args['end_date_time'];
                    final int priority = args['priority'] ?? 3;

                    // Parse dates
                    final DateTime start = DateTime.parse(startDateTimeStr);
                    final DateTime end = endDateTimeStr != null
                        ? DateTime.parse(endDateTimeStr)
                        : start.add(const Duration(hours: 1));

                    final String dateOnCalendar =
                        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
                    final String startTime =
                        "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
                    final String endTime =
                        "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";

                    // Execute adding task
                    addManualTask({
                      'task': title,
                      'Description': description,
                      'dateOnCalendar': dateOnCalendar,
                      'start_time': startTime,
                      'end_time': endTime,
                      'priority': priority,
                      'isManuallyScheduled': true,
                    });

                    // Update UI response
                    aiText =
                        "✅ **Added Task:** $title\n📅 $dateOnCalendar at $startTime - $endTime";

                    // Update message in project
                    if (_activeProjectId != null) {
                      final projectIndex = _projects.indexWhere(
                        (p) => p.id == _activeProjectId,
                      );
                      if (projectIndex != -1) {
                        final currentMessages = List<Message>.from(
                          _projects[projectIndex].messages,
                        );
                        final msgIndex = currentMessages.indexWhere(
                          (m) => m.id == assistantMessageId,
                        );
                        if (msgIndex != -1) {
                          currentMessages[msgIndex] = currentMessages[msgIndex]
                              .copyWith(text: aiText);
                          _projects[projectIndex] = _projects[projectIndex]
                              .copyWith(messages: currentMessages);
                        }
                      }
                    }
                    notifyListeners();
                  } catch (e) {
                    debugPrint('Error executing add_calendar_task: $e');
                    aiText += "\n\n❌ Error adding task: $e";
                    notifyListeners();
                  }
                } else if (name == 'task_and_schedule_planer' &&
                    arguments != null &&
                    callId != null) {
                  String? topic;
                  try {
                    final argsJson = jsonDecode(arguments);
                    topic = argsJson['topic'] as String?;
                  } catch (e) {
                    debugPrint('Error parsing tool arguments: $e');
                  }

                  if (topic != null) {
                    // Initialize MCP client if needed (or reset if previous connection broke)
                    if (_mcpClient == null || !_isApiAvailable) {
                      disposeMcpClient();
                      await _initMcpClient();
                    }

                    if (_mcpClient == null || !_isApiAvailable) {
                      aiText +=
                          '\n\n*Error: Task planning service unavailable.*\n';
                      notifyListeners();
                      continue;
                    }

                    // CHECK 1: Cancel before starting the tool
                    if (_cancelledRequests.contains(requestId)) {
                      debugPrint(
                        'Request $requestId cancelled before MCP tool execution',
                      );
                      return;
                    }

                    // Don't show the raw topic - just process silently
                    try {
                      final result = await _mcpClient!.callTool(
                        CallToolRequest(
                          name: 'task_and_schedule_planer',
                          arguments: {'topic': topic},
                        ),
                      );

                      // CHECK 2: Cancel after tool execution (before processing results)
                      if (_cancelledRequests.contains(requestId)) {
                        debugPrint(
                          'Request $requestId cancelled after MCP tool execution',
                        );
                        return;
                      }

                      // Process result
                      final content = result.content;
                      String toolOutput = '';
                      if (content.isNotEmpty) {
                        final dynamic first = content.first;
                        try {
                          toolOutput = first.text;
                        } catch (_) {
                          toolOutput = first.toString();
                        }
                      }

                      // Parse the JSON output into tasks
                      final tasks = _parseMcpResult(toolOutput);

                      if (tasks.isNotEmpty) {
                        // Compute TimeToComplete for each task
                        for (final task in tasks) {
                          _computeTimeToComplete(task);
                        }

                        // Generate task summary for the AI message
                        final taskSummary = tasks
                            .map((t) {
                              final name = t['task'] ?? 'Unnamed';
                              final dueDate = t['DueDate'] ?? 'No due date';
                              final priority = t['priority'] ?? 3;
                              final priorityEmoji = priority == 1
                                  ? '🔴'
                                  : (priority == 2 ? '🟡' : '🟢');
                              return '- $priorityEmoji **$name** (Due: $dueDate)';
                            })
                            .join('\n');

                        // Don't auto-save - attach tasks to message for display as task cards
                        // User clicks "Done" button to save to calendar
                        aiText =
                            '''Here's a summary of your planned tasks:

$taskSummary

Review and edit the tasks below, then click **Done** to add them to your calendar:''';

                        // Update message in project with tasks attached
                        if (_activeProjectId != null) {
                          final projectIndex = _projects.indexWhere(
                            (p) => p.id == _activeProjectId,
                          );
                          if (projectIndex != -1) {
                            final currentMessages = List<Message>.from(
                              _projects[projectIndex].messages,
                            );
                            final msgIndex = currentMessages.indexWhere(
                              (m) => m.id == assistantMessageId,
                            );
                            if (msgIndex != -1) {
                              currentMessages[msgIndex] =
                                  currentMessages[msgIndex].copyWith(
                                    text: aiText,
                                    tasks:
                                        tasks, // Attach tasks for card display
                                  );
                              _projects[projectIndex] = _projects[projectIndex]
                                  .copyWith(messages: currentMessages);
                            }
                          }
                        }
                      } else {
                        aiText +=
                            '\n\n*No tasks could be created from the plan.*\n';

                        // Update message in project
                        if (_activeProjectId != null) {
                          final projectIndex = _projects.indexWhere(
                            (p) => p.id == _activeProjectId,
                          );
                          if (projectIndex != -1) {
                            final currentMessages = List<Message>.from(
                              _projects[projectIndex].messages,
                            );
                            final msgIndex = currentMessages.indexWhere(
                              (m) => m.id == assistantMessageId,
                            );
                            if (msgIndex != -1) {
                              currentMessages[msgIndex] =
                                  currentMessages[msgIndex].copyWith(
                                    text: aiText,
                                  );
                              _projects[projectIndex] = _projects[projectIndex]
                                  .copyWith(messages: currentMessages);
                            }
                          }
                        }
                      }

                      notifyListeners();
                    } catch (e) {
                      debugPrint('MCP Tool Execution Error: $e');
                      aiText += '\n\n*Error executing plan: $e*';
                      notifyListeners();
                    }
                  }
                } else if (name == 'check_gmail' && callId != null) {
                  // Parse optional arguments
                  String gmailQuery = 'is:inbox';
                  int maxResults = 10;
                  if (arguments != null) {
                    try {
                      final argsJson = jsonDecode(arguments);
                      gmailQuery = argsJson['query'] as String? ?? 'is:inbox';
                      maxResults = argsJson['max_results'] as int? ?? 10;
                    } catch (e) {
                      debugPrint('Error parsing check_gmail arguments: $e');
                    }
                  }

                  // Show loading message
                  aiText = '*📧 Checking your Gmail...*';
                  if (_activeProjectId != null) {
                    final projectIndex = _projects.indexWhere(
                      (p) => p.id == _activeProjectId,
                    );
                    if (projectIndex != -1) {
                      final currentMessages = List<Message>.from(
                        _projects[projectIndex].messages,
                      );
                      final msgIndex = currentMessages.indexWhere(
                        (m) => m.id == assistantMessageId,
                      );
                      if (msgIndex != -1) {
                        currentMessages[msgIndex] = currentMessages[msgIndex]
                            .copyWith(text: aiText);
                        _projects[projectIndex] = _projects[projectIndex]
                            .copyWith(messages: currentMessages);
                        notifyListeners();
                      }
                    }
                  }

                  // Initialize MCP client if needed (or reset if previous connection broke)
                  if (_mcpClient == null || !_isApiAvailable) {
                    // Force cleanup of any stale connection
                    disposeMcpClient();
                    await _initMcpClient();
                  }

                  if (_mcpClient == null || !_isApiAvailable) {
                    aiText =
                        '❌ *Email service unavailable. Please ensure the backend is running.*';
                    notifyListeners();
                    continue;
                  }

                  if (_cancelledRequests.contains(requestId)) {
                    return;
                  }

                  try {
                    final result = await _mcpClient!.callTool(
                      CallToolRequest(
                        name: 'check_gmail',
                        arguments: {
                          'query': gmailQuery,
                          'max_results': maxResults,
                          'user_id': _currentUserEmail ?? 'default',
                        },
                      ),
                    );

                    if (_cancelledRequests.contains(requestId)) {
                      return;
                    }

                    // Parse the MCP result
                    final content = result.content;
                    String toolOutput = '';
                    if (content.isNotEmpty) {
                      final dynamic first = content.first;
                      try {
                        toolOutput = first.text;
                      } catch (_) {
                        toolOutput = first.toString();
                      }
                    }

                    // Send the tool output back to the AI for natural language summarization
                    // Use the responseId tracked from the outer streaming scope

                    final summaryBody = jsonEncode({
                      'model': 'gpt-4.1-mini',
                      'stream': true,
                      'input': [
                        {
                          'type': 'function_call_output',
                          'call_id': callId,
                          'output': toolOutput,
                        },
                      ],
                      if (responseId.isNotEmpty)
                        'previous_response_id': responseId,
                      'instructions':
                          'Summarize the email results in a friendly, concise way. Highlight unread emails and important subjects. Use markdown formatting with emojis. Keep it brief and readable.',
                    });

                    final summaryRequest = http.Request(
                      'POST',
                      Uri.parse('https://api.openai.com/v1/responses'),
                    );
                    summaryRequest.headers.addAll({
                      'Authorization': 'Bearer $apiKey',
                      'Content-Type': 'application/json',
                    });
                    summaryRequest.body = summaryBody;

                    final summaryStreamResponse = await http.Client().send(
                      summaryRequest,
                    );

                    aiText = '';
                    notifyListeners();

                    await for (final chunk
                        in summaryStreamResponse.stream
                            .transform(utf8.decoder)
                            .transform(const LineSplitter())) {
                      if (_cancelledRequests.contains(requestId)) {
                        return;
                      }

                      if (chunk.startsWith('data: ')) {
                        final jsonStr = chunk.substring(6).trim();
                        if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
                        try {
                          final summaryEvent =
                              jsonDecode(jsonStr) as Map<String, dynamic>;
                          final summaryType =
                              summaryEvent['type'] as String? ?? '';

                          if (summaryType == 'response.output_text.delta') {
                            final delta =
                                summaryEvent['delta'] as String? ?? '';
                            aiText += delta;

                            // Update message in project
                            if (_activeProjectId != null) {
                              final projectIndex = _projects.indexWhere(
                                (p) => p.id == _activeProjectId,
                              );
                              if (projectIndex != -1) {
                                final currentMessages = List<Message>.from(
                                  _projects[projectIndex].messages,
                                );
                                final msgIndex = currentMessages.indexWhere(
                                  (m) => m.id == assistantMessageId,
                                );
                                if (msgIndex != -1) {
                                  currentMessages[msgIndex] =
                                      currentMessages[msgIndex].copyWith(
                                        text: aiText,
                                      );
                                  _projects[projectIndex] =
                                      _projects[projectIndex].copyWith(
                                        messages: currentMessages,
                                      );
                                  notifyListeners();
                                }
                              }
                            }
                          }
                        } catch (_) {}
                      }
                    }

                    // Final update
                    if (_activeProjectId != null) {
                      final projectIndex = _projects.indexWhere(
                        (p) => p.id == _activeProjectId,
                      );
                      if (projectIndex != -1) {
                        final currentMessages = List<Message>.from(
                          _projects[projectIndex].messages,
                        );
                        final msgIndex = currentMessages.indexWhere(
                          (m) => m.id == assistantMessageId,
                        );
                        if (msgIndex != -1) {
                          currentMessages[msgIndex] = currentMessages[msgIndex]
                              .copyWith(text: aiText);
                          _projects[projectIndex] = _projects[projectIndex]
                              .copyWith(messages: currentMessages);
                        }
                      }
                    }

                    notifyListeners();
                  } catch (e) {
                    debugPrint('Gmail MCP Tool Error: $e');
                    aiText = '❌ *Error checking Gmail: $e*';
                    notifyListeners();
                  }
                } else if (name == 'switch_gmail_account' && callId != null) {
                  // Show loading message
                  aiText = '*🔄 Switching Gmail account...*';
                  if (_activeProjectId != null) {
                    final projectIndex = _projects.indexWhere(
                      (p) => p.id == _activeProjectId,
                    );
                    if (projectIndex != -1) {
                      final currentMessages = List<Message>.from(
                        _projects[projectIndex].messages,
                      );
                      final msgIndex = currentMessages.indexWhere(
                        (m) => m.id == assistantMessageId,
                      );
                      if (msgIndex != -1) {
                        currentMessages[msgIndex] = currentMessages[msgIndex]
                            .copyWith(text: aiText);
                        _projects[projectIndex] = _projects[projectIndex]
                            .copyWith(messages: currentMessages);
                        notifyListeners();
                      }
                    }
                  }

                  // Initialize MCP client if needed
                  if (_mcpClient == null || !_isApiAvailable) {
                    disposeMcpClient();
                    await _initMcpClient();
                  }

                  if (_mcpClient == null || !_isApiAvailable) {
                    aiText =
                        '❌ *Service unavailable. Please ensure the backend is running.*';
                    notifyListeners();
                    continue;
                  }

                  try {
                    final result = await _mcpClient!.callTool(
                      CallToolRequest(
                        name: 'switch_gmail_account',
                        arguments: {'user_id': _currentUserEmail ?? 'default'},
                      ),
                    );

                    final content = result.content;
                    String toolOutput = '';
                    if (content.isNotEmpty) {
                      final dynamic first = content.first;
                      try {
                        toolOutput = first.text;
                      } catch (_) {
                        toolOutput = first.toString();
                      }
                    }

                    try {
                      final data = jsonDecode(toolOutput);
                      if (data['error'] != null) {
                        aiText = '❌ ${data['error']}';
                      } else {
                        aiText =
                            '✅ **Gmail 帳號已登出！**\n\n下次查看 email 時，會自動開啟 Google 登入頁面讓你選擇新帳號。\n\n你可以直接說「**查看我的 email**」來登入新帳號。';
                      }
                    } catch (_) {
                      aiText = '✅ Gmail 帳號已切換，下次查看 email 會重新登入。';
                    }

                    // Update message
                    if (_activeProjectId != null) {
                      final projectIndex = _projects.indexWhere(
                        (p) => p.id == _activeProjectId,
                      );
                      if (projectIndex != -1) {
                        final currentMessages = List<Message>.from(
                          _projects[projectIndex].messages,
                        );
                        final msgIndex = currentMessages.indexWhere(
                          (m) => m.id == assistantMessageId,
                        );
                        if (msgIndex != -1) {
                          currentMessages[msgIndex] = currentMessages[msgIndex]
                              .copyWith(text: aiText);
                          _projects[projectIndex] = _projects[projectIndex]
                              .copyWith(messages: currentMessages);
                        }
                      }
                    }
                    notifyListeners();
                  } catch (e) {
                    debugPrint('Switch Gmail Error: $e');
                    aiText = '❌ *切換 Gmail 帳號失敗: $e*';
                    notifyListeners();
                  }
                }
              } else if (type == 'response.error') {
                final error = event['error'] as Map<String, dynamic>?;
                if (error != null) {
                  final msg = error['message'] as String? ?? 'Unknown error';
                  debugPrint('⚠️ AI Response Error Event: $msg');
                  aiText += '\n\n*System Error: $msg*\n';
                }
              } else if (type == 'response.completed') {
                // Final response - extract any remaining data
                final response = event['response'] as Map<String, dynamic>?;
                if (response != null) {
                  final outputText = response['output_text'] as String?;
                  final status = response['status'] as String?;

                  if (status == 'failed') {
                    final error = response['error'] as Map<String, dynamic>?;
                    if (error != null) {
                      final msg = error['message'] as String? ?? 'FAILED';
                      aiText += '\n\n*Response failed: $msg*\n';
                    }
                  }

                  if (outputText != null && outputText.isNotEmpty) {
                    // Only use if aiText is currently very short (mostly status markers)
                    if (aiText.length < 50 ||
                        !aiText.contains(
                          outputText.substring(
                            0,
                            math.min(10, outputText.length),
                          ),
                        )) {
                      if (aiText.isNotEmpty) aiText += '\n\n';
                      aiText += outputText;
                    }
                  }
                }
              }
            } catch (e) {
              // Skip malformed JSON - might still be partial
              debugPrint('Stream parse error (may recover): $e');
            }
          }
        }
      }

      // Add sources from annotations
      if (annotations.isNotEmpty) {
        aiText += '\n\n**Sources:**\n';
        final uniqueUrls = <String>{};
        for (final annotation in annotations) {
          final url = annotation['url'] as String?;
          if (url != null && !uniqueUrls.contains(url)) {
            uniqueUrls.add(url);
            final title = annotation['title'] as String? ?? url;
            aiText += '- [$title]($url)\n';
          }
        }
      }

      if (aiText.isEmpty) {
        aiText = "I couldn't generate a response. Please try again.";
      }

      // Final update to ensure complete text is saved
      if (_activeProjectId != null) {
        final projectIndex = _projects.indexWhere(
          (p) => p.id == _activeProjectId,
        );
        if (projectIndex != -1) {
          final currentMessages = List<Message>.from(
            _projects[projectIndex].messages,
          );
          final msgIndex = currentMessages.indexWhere(
            (m) => m.id == assistantMessageId,
          );

          if (msgIndex != -1) {
            currentMessages[msgIndex] = currentMessages[msgIndex].copyWith(
              text: aiText,
            );
            final updatedProject = _projects[projectIndex].copyWith(
              messages: currentMessages,
            );
            _projects[projectIndex] = updatedProject;
            notifyListeners();
          }
        }
      }

      // Save to storage
      await _saveProjects();

      // Add to memory
      _shortTermMemory.addMessageWithId(
        assistantMessageId,
        aiText,
        'assistant',
      );

      // Save for semantic search
      if (_activeProjectId != null) {
        // Retrieve the full message from the project to ensure we include any attached tasks
        // that were added during the stream processing
        Message? fullMessage;
        try {
          final project = _projects.firstWhere((p) => p.id == _activeProjectId);
          fullMessage = project.messages.firstWhere(
            (m) => m.id == assistantMessageId,
            orElse: () => throw Exception('Message not found'),
          );
        } catch (_) {
          // Fallback if not found (shouldn't happen)
          fullMessage = Message(
            id: assistantMessageId,
            role: MessageRole.model,
            text: aiText,
            timestamp: DateTime.now(),
          );
        }

        _saveMessageToObjectBox(fullMessage, _activeProjectId!);
      }
    } catch (e) {
      debugPrint('Responses API Error: $e');

      // Update placeholder with error message
      final errorText = 'Sorry, I encountered an error. Please try again.';
      if (_activeProjectId != null) {
        final projectIndex = _projects.indexWhere(
          (p) => p.id == _activeProjectId,
        );
        if (projectIndex != -1) {
          final currentMessages = List<Message>.from(
            _projects[projectIndex].messages,
          );
          final msgIndex = currentMessages.indexWhere(
            (m) => m.id == assistantMessageId,
          );
          if (msgIndex != -1) {
            currentMessages[msgIndex] = currentMessages[msgIndex].copyWith(
              text: errorText,
            );
            _projects[projectIndex] = _projects[projectIndex].copyWith(
              messages: currentMessages,
            );
            notifyListeners();
          }
        }
      }
    }
  }

  /// Send a message to the Global Assistant
  /// Send a message to the Global Assistant
  Future<void> sendGlobalMessage(
    String text, {
    List<Map<String, String>>? attachments,
  }) async {
    if (text.trim().isEmpty && (attachments == null || attachments.isEmpty)) {
      return;
    }

    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      text: text,
      timestamp: DateTime.now(),
      attachments: attachments,
    );

    _globalMessages
        .clear(); // Clear display history to focus on current interaction
    _globalMessages.add(userMessage);
    _isLoading = true;
    notifyListeners();

    final assistantMessageId = (DateTime.now().millisecondsSinceEpoch + 1)
        .toString();
    final placeholder = Message(
      id: assistantMessageId,
      role: MessageRole.model,
      text: 'Thinking...',
      timestamp: DateTime.now(),
    );
    _globalMessages.add(placeholder);

    final requestId = ++_requestCounter;
    _currentRequestId = requestId;

    try {
      await _getGlobalAgentResponse(text, requestId: requestId);
    } catch (e) {
      debugPrint('Global Assistant Error: $e');
      final msgIndex = _globalMessages.indexWhere(
        (m) => m.id == assistantMessageId,
      );
      if (msgIndex != -1) {
        _globalMessages[msgIndex] = _globalMessages[msgIndex].copyWith(
          text: 'Sorry, I encountered an error: $e',
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendGlobalAudioMessage(String filePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) {
        throw Exception('OpenAI API Key not found');
      }

      final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = 'whisper-1'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        final transcript = data['text'] as String;

        // Send transcribed text as a message
        await sendGlobalMessage(
          transcript,
          attachments: [
            {'type': 'audio', 'path': filePath},
          ],
        );
      } else {
        throw Exception('Transcription failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending global audio message: $e');
      final errorMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.model,
        text: "I couldn't transcribe the audio. Error: $e",
        timestamp: DateTime.now(),
      );
      _globalMessages.clear();
      _globalMessages.add(errorMsg);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _getGlobalAgentResponse(
    String userText, {
    required int requestId,
  }) async {
    // Initialize MCP client if needed so tools can work
    if (_mcpClient == null) {
      await _initMcpClient();
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null) throw Exception('API Key not found');

    final assistantMessageId = _globalMessages.last.id;
    final agentTools = GlobalAgentTools(this);

    // Filter out local web_search to use server-side one
    final localTools = GlobalAgentTools.restrictedTools
        .where((t) => t['function']['name'] != 'web_search')
        .map((t) {
          final func = t['function'] as Map<String, dynamic>;
          return {
            'type': 'function',
            'name': func['name'],
            'description': func['description'],
            'parameters': func['parameters'],
          };
        })
        .toList();

    // Combine server-side web search with local tools
    final tools = [
      {'type': 'web_search'},
      ...localTools,
    ];

    // Build conversation history
    final history = _globalShortTermMemory.getMessages();
    final List<Map<String, dynamic>> items = [];
    for (final msg in history) {
      final role = msg['role'] == 'user' ? 'user' : 'assistant';
      items.add({
        'type': 'message',
        'role': role,
        'content': [
          {
            'type': role == 'user' ? 'input_text' : 'output_text',
            'text': msg['content'] ?? '',
          },
        ],
      });
    }
    items.add({
      'type': 'message',
      'role': 'user',
      'content': [
        {'type': 'input_text', 'text': userText},
      ],
    });

    final instructions =
        'You are DayCrafter, a fast personal assistant. Be brief and direct. '
        'Use tools only when needed. Current time: ${DateTime.now().toIso8601String()}.';

    final request = http.Request(
      'POST',
      Uri.parse('https://api.openai.com/v1/responses'),
    );
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'model': 'gpt-4.1-mini',
      'instructions': instructions,
      'input': items,
      'tools': tools,
      'tool_choice': 'auto',
      'stream': true,
    });

    final streamedResponse = await http.Client().send(request);
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      debugPrint('API Error: $body');
      throw Exception('OpenAI API Error: ${streamedResponse.statusCode}');
    }

    String aiText = "";
    // Track pending function calls: itemId -> {name, call_id, arguments}
    final pendingFunctionCalls = <String, Map<String, dynamic>>{};
    bool hasToolCalls = false;

    // Phase 1: Parse the initial stream, collect tool calls OR stream text directly
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      if (_cancelledRequests.contains(requestId)) return;

      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.isEmpty || !line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') continue;

        try {
          final event = jsonDecode(data);
          final type = event['type'] as String?;

          if (type == 'response.output_text.delta' ||
              type == 'response.text.delta') {
            // Direct text response (no tool calls) — stream it
            final delta = event['delta'] as String?;
            if (delta != null) {
              aiText += delta;
              final msgIndex = _globalMessages.indexWhere(
                (m) => m.id == assistantMessageId,
              );
              if (msgIndex != -1) {
                _globalMessages[msgIndex] = _globalMessages[msgIndex].copyWith(
                  text: aiText,
                );
                notifyListeners();
              }
            }
          } else if (type == 'response.output_item.added') {
            final item = event['item'];
            if (item != null && item['type'] == 'function_call') {
              hasToolCalls = true;
              final itemId = item['id'];
              final callId = item['call_id'];
              final name = item['name'];
              pendingFunctionCalls[itemId] = {'name': name, 'call_id': callId};

              // Show thinking status
              final msgIndex = _globalMessages.indexWhere(
                (m) => m.id == assistantMessageId,
              );
              if (msgIndex != -1) {
                _globalMessages[msgIndex] = _globalMessages[msgIndex].copyWith(
                  text: '*Gathering information...*',
                );
                notifyListeners();
              }
            }
          } else if (type == 'response.function_call_arguments.done') {
            final itemId = event['item_id'];
            final arguments = event['arguments'];
            if (pendingFunctionCalls.containsKey(itemId)) {
              pendingFunctionCalls[itemId]!['arguments'] = arguments;
            }
          }
        } catch (_) {}
      }
    }

    // Phase 2: If tool calls were made, execute them all in parallel
    if (hasToolCalls && pendingFunctionCalls.isNotEmpty) {
      // Execute all tools in parallel
      final toolEntries = pendingFunctionCalls.entries.toList();
      final futures = toolEntries.map((entry) async {
        final name = entry.value['name'] as String;
        final arguments = entry.value['arguments'] as String? ?? '{}';

        final output = await agentTools.executeTool(name, arguments);

        return MapEntry(name, output);
      }).toList();

      final results = await Future.wait(futures);

      // Phase 3: Send a single follow-up API call with user question + all tool results

      // Build tool context
      final toolContext = results
          .map(
            (r) =>
                '## ${r.key.replaceAll("_", " ").toUpperCase()} Result:\n${r.value}',
          )
          .join('\n\n');

      final followUpBody = jsonEncode({
        'model': 'gpt-4.1-mini',
        'stream': true,
        'input': [
          {
            'type': 'message',
            'role': 'user',
            'content': [
              {
                'type': 'input_text',
                'text':
                    'User question: $userText\n\nHere is the data:\n$toolContext\n\nPlease answer the user question based on the data above.',
              },
            ],
          },
        ],
        'instructions':
            'Answer the user based on the data provided. '
            'Be direct and concise. '
            'Never mention tool names or internal details. '
            'Current time: ${DateTime.now().toIso8601String()}.',
      });

      final followUpReq = http.Request(
        'POST',
        Uri.parse('https://api.openai.com/v1/responses'),
      );
      followUpReq.headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      });
      followUpReq.body = followUpBody;

      // Clear the "Gathering information..." text
      aiText = '';
      final clearIdx = _globalMessages.indexWhere(
        (m) => m.id == assistantMessageId,
      );
      if (clearIdx != -1) {
        _globalMessages[clearIdx] = _globalMessages[clearIdx].copyWith(
          text: '',
        );
        notifyListeners();
      }

      final followUpResp = await http.Client().send(followUpReq);

      if (followUpResp.statusCode == 200) {
        await for (final sumChunk in followUpResp.stream.transform(
          utf8.decoder,
        )) {
          if (_cancelledRequests.contains(requestId)) return;
          final sumLines = sumChunk.split('\n');
          for (final sl in sumLines) {
            if (sl.startsWith('data: ')) {
              final dataStr = sl.substring(6).trim();
              if (dataStr == '[DONE]') continue;
              try {
                final se = jsonDecode(dataStr);
                final eventType = se['type'] as String?;

                if (eventType == 'response.output_item.done') {}
                if (eventType == 'response.incomplete') {}
                if (eventType == 'response.output_text.delta' ||
                    eventType == 'response.text.delta') {
                  aiText += se['delta'] ?? '';
                  final idx = _globalMessages.indexWhere(
                    (m) => m.id == assistantMessageId,
                  );
                  if (idx != -1) {
                    _globalMessages[idx] = _globalMessages[idx].copyWith(
                      text: aiText,
                    );
                    notifyListeners();
                  }
                } else if (eventType == 'response.completed' &&
                    aiText.isEmpty) {
                  // Fallback: extract text from completed response
                  try {
                    final output = se['response']?['output'] as List?;
                    if (output != null) {
                      for (final item in output) {
                        final content = item['content'] as List?;
                        if (content != null) {
                          for (final c in content) {
                            if (c['text'] != null) {
                              aiText = c['text'];
                              final idx = _globalMessages.indexWhere(
                                (m) => m.id == assistantMessageId,
                              );
                              if (idx != -1) {
                                _globalMessages[idx] = _globalMessages[idx]
                                    .copyWith(text: aiText);
                                notifyListeners();
                              }
                            }
                          }
                        }
                      }
                    }
                  } catch (e) {
                    debugPrint('❌ Fallback extraction failed: $e');
                  }
                }
              } catch (_) {}
            }
          }
        }
      } else {
        final errorBody = await followUpResp.stream.bytesToString();
        debugPrint('❌ Follow-up API error: $errorBody');
        // Fallback: show a friendly message with the raw data
        aiText = results
            .map((r) => r.value)
            .where((v) => v.isNotEmpty && !v.startsWith('Error'))
            .join('\n\n');
        if (aiText.isEmpty)
          aiText = 'Sorry, I had trouble processing that request.';
        final idx = _globalMessages.indexWhere(
          (m) => m.id == assistantMessageId,
        );
        if (idx != -1) {
          _globalMessages[idx] = _globalMessages[idx].copyWith(text: aiText);
          notifyListeners();
        }
      }
    }

    // Save to memory
    _globalShortTermMemory.addMessage(userText, 'user');
    _globalShortTermMemory.addMessage(aiText, 'assistant');

    // Final cleanup — ensure message is updated
    final finalIndex = _globalMessages.indexWhere(
      (m) => m.id == assistantMessageId,
    );
    if (finalIndex != -1) {
      _globalMessages[finalIndex] = _globalMessages[finalIndex].copyWith(
        text: aiText,
      );
      notifyListeners();
    }
  }

  /// Cancel the current in-flight AI request (best-effort).
  void cancelCurrentRequest() {
    if (_currentRequestId != null) {
      _cancelledRequests.add(_currentRequestId!);
      _isLoading = false;

      // If the last message is an empty/loading assistant message, update it to say "Cancelled"
      if (_activeProjectId != null) {
        final projectIndex = _projects.indexWhere(
          (p) => p.id == _activeProjectId,
        );
        if (projectIndex != -1) {
          final project = _projects[projectIndex];
          if (project.messages.isNotEmpty) {
            final lastMsg = project.messages.last;
            if (lastMsg.role == MessageRole.model &&
                (lastMsg.text.isEmpty ||
                    lastMsg.text ==
                        '*Creating your tasks (about 1 minute)...*')) {
              // Create updated message list
              final updatedMessages = List<Message>.from(project.messages);
              updatedMessages[updatedMessages.length - 1] = lastMsg.copyWith(
                text: '*Request cancelled*',
              );

              // Update project
              _projects[projectIndex] = project.copyWith(
                messages: updatedMessages,
              );
            }
          }
        }
      } else {
        // Handle cancellation for global agent messages
        if (_globalMessages.isNotEmpty) {
          final lastMsg = _globalMessages.last;
          if (lastMsg.role == MessageRole.model && lastMsg.text.isEmpty) {
            _globalMessages[_globalMessages.length - 1] = lastMsg.copyWith(
              text: '*Request cancelled*',
            );
          }
        }
      }

      notifyListeners();
    }
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

  /// Public wrapper for initializing MCP Client
  Future<void> initMcpClient({bool force = false}) =>
      _initMcpClient(force: force);

  /// Initialize MCP Client connection
  Future<void> _initMcpClient({bool force = false}) async {
    if (_mcpClient != null && !force) return;

    try {
      if (force) {
        _mcpClient = null;
        _mcpProcess?.kill();
        _mcpProcess = null;
      }

      // Path to python server script
      String serverPath = 'MCP_tools/mcp_server.py';

      // Check for virtual environment
      String pythonCommand = 'python3';
      final venvPython = File(
        serverPath.replaceAll('mcp_server.py', '.venv/bin/python'),
      );
      if (await venvPython.exists()) {
        pythonCommand = venvPython.path;
      }

      // Launch Python process
      _mcpProcess = await Process.start(pythonCommand, [serverPath]);

      // Connect via IOStreamTransport (mcp_dart uses this for stdio)
      final transport = IOStreamTransport(
        stream: _mcpProcess!.stdout,
        sink: _mcpProcess!.stdin,
      );

      // Create client with implementation info
      _mcpClient = McpClient(
        Implementation(name: 'DayCrafterClient', version: '1.0.0'),
      );

      // Connect to transport
      await _mcpClient!.connect(transport);

      // List tools to verify connection
      await _mcpClient!.listTools();

      _isApiAvailable = true;
    } catch (e) {
      debugPrint('❌ Failed to initialize MCP client: $e');
      // Clean up broken state so next attempt retries from scratch
      _mcpProcess?.kill();
      _mcpProcess = null;
      _mcpClient = null;
      _isApiAvailable = false;
    }
  }

  /// Dispose MCP client and kill Python process
  void disposeMcpClient() {
    _mcpProcess?.kill();
    _mcpClient = null;
    _isApiAvailable = false;
  }

  Future<List<Map<String, dynamic>>?> _getTasks(String userText) async {
    // Ensure client is initialized
    if (_mcpClient == null) {
      await _initMcpClient();
    }

    if (_mcpClient == null || !_isApiAvailable) {
      debugPrint('⚠️ MCP Client unavailable');
      return null;
    }

    try {
      debugPrint('🚀 Calling MCP tool: task_and_schedule_planer');

      // Call the tool
      final result = await _mcpClient!.callTool(
        CallToolRequest(
          name: 'task_and_schedule_planer',
          arguments: {'topic': userText},
        ),
      );

      // Extract text content from result
      String rawResult = '';
      if (result.content.isNotEmpty) {
        // Assuming the first content block is the text result
        final block = result.content.first;
        if (block is TextContent) {
          rawResult = block.text;
        } else {
          debugPrint('⚠️ Unexpected content type: ${block.runtimeType}');
          rawResult = block.toString();
        }
      }

      // Parse the result into tasks list
      final tasks = _parseMcpResult(rawResult);
      if (tasks.isEmpty) {
        debugPrint('⚠️ MCP returned empty tasks');
        return null;
      }

      // Compute TimeToComplete from Start and Due dates for each task
      for (final task in tasks) {
        _computeTimeToComplete(task);
      }

      return tasks;
    } catch (e) {
      debugPrint('❌ MCP Execution Error: $e');
      return null;
    }
  }

  /// Build token-efficient conversation history with compression
  /// Parse MCP result into tasks list
  List<Map<String, dynamic>> _parseMcpResult(dynamic result) {
    if (result == null) return [];

    // If result is already a list, use it directly
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }

    // If result is a string (JSON), parse it
    if (result is String) {
      String jsonStr = result;

      // Try direct parse first
      try {
        final parsed = jsonDecode(jsonStr);
        if (parsed is List) {
          return parsed.cast<Map<String, dynamic>>();
        }
      } catch (_) {
        // If direct parse fails, try to extract JSON from the string
        // This handles cases where MCP returns "Thought: ..." before the JSON
        debugPrint('Direct JSON parse failed, attempting to extract JSON...');
      }

      // Try to find and extract JSON array from the string
      try {
        // Look for JSON array starting with '['
        final startIndex = jsonStr.indexOf('[');
        if (startIndex != -1) {
          // Find matching closing bracket
          int bracketCount = 0;
          int endIndex = -1;
          for (int i = startIndex; i < jsonStr.length; i++) {
            if (jsonStr[i] == '[') bracketCount++;
            if (jsonStr[i] == ']') bracketCount--;
            if (bracketCount == 0) {
              endIndex = i;
              break;
            }
          }

          if (endIndex != -1 && endIndex > startIndex) {
            final extractedJson = jsonStr.substring(startIndex, endIndex + 1);
            final parsed = jsonDecode(extractedJson);
            if (parsed is List) {
              debugPrint('✅ Successfully extracted JSON array from MCP result');
              return parsed.cast<Map<String, dynamic>>();
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to extract JSON from MCP result: $e');
      }
    }

    // If result is a map with 'tasks' or 'data' key
    if (result is Map<String, dynamic>) {
      if (result['tasks'] is List) {
        return result['tasks'].cast<Map<String, dynamic>>();
      }
      if (result['data'] is List) {
        return result['data'].cast<Map<String, dynamic>>();
      }
    }

    return [];
  }

  Future<void> _saveProjects() async {
    final prefs = await SharedPreferences.getInstance();

    // Use user-specific key if logged in
    final key = _currentUserEmail != null
        ? '${_currentUserEmail}_projects'
        : 'daycrafter_projects';

    final projectsJson = jsonEncode(_projects.map((p) => p.toJson()).toList());
    await prefs.setString(key, projectsJson);

    // Also save to ObjectBox for robust storage
    if (_currentUserEmail != null) {
      try {
        final db = ObjectBoxService.instance;
        if (db.isInitialized) {
          for (final project in _projects) {
            await db.saveProjectFromDomain(
              project,
              userEmail: _currentUserEmail,
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to sync projects to ObjectBox: $e');
      }
    }
  }

  /// Check if a message is the latest task message in the active project
  bool isLatestTaskMessage(String messageId) {
    if (_activeProjectId == null) return false;

    final project = activeProject;
    if (project == null) return false;

    // Find the last message with tasks
    for (int i = project.messages.length - 1; i >= 0; i--) {
      final msg = project.messages[i];
      if (msg.tasks != null && msg.tasks!.isNotEmpty) {
        return msg.id == messageId;
      }
    }

    return false;
  }

  /// Get the latest task message in the active project
  Message? getLatestTaskMessage() {
    if (_activeProjectId == null) return null;

    final project = activeProject;
    if (project == null) return null;

    // Find the last message with tasks
    for (int i = project.messages.length - 1; i >= 0; i--) {
      final msg = project.messages[i];
      if (msg.tasks != null && msg.tasks!.isNotEmpty) {
        return msg;
      }
    }

    return null;
  }

  /// Deletes a project and cleans up its changelog
  Future<void> deleteProject(String projectId) async {
    // 1. Delete persistent memory for this project
    await _deleteProjectMemory(projectId);

    _projects.removeWhere((p) => p.id == projectId);

    // CRM-style cascade delete: removes project, messages, and tasks from DB
    ObjectBoxService.instance.deleteProjectByUuid(projectId);

    // EXTRA SAFETY: Explicitly ensure no tasks for this projectId remain
    // This handles cases where manual tasks might have been orphaned
    ObjectBoxService.instance.deleteCalendarTasksForProject(projectId);

    // Switch to another project if deleted the active one
    if (_activeProjectId == projectId) {
      // Prevent saving the deleted project's memory in setActiveProject
      _activeProjectId = null;

      // Clear current RAM memory immediately
      _shortTermMemory.clear();

      final nextProjectId = _projects.isNotEmpty ? _projects.first.id : null;
      setActiveProject(nextProjectId);
    } else {
      await _saveProjects();
      notifyListeners();
    }

    // Debug verification
    final db = ObjectBoxService.instance;
    final allTasks = db.getAllCalendarTasks(userEmail: _currentUserEmail);
    debugPrint(
      '🔎 DEBUG check: Project $projectId deleted. User has ${allTasks.length} total tasks remaining in DB.',
    );
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

    // Re-generate embedding for the updated message
    // This ensures semantic search can find this task based on new edits
    await _saveMessageToObjectBox(updatedMessage, _activeProjectId!);

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

  /// Search calendar tasks using semantic search
  /// Generates embedding for query and compares with task content
  /// Returns matching tasks sorted by relevance
  Future<List<Map<String, dynamic>>> semanticSearchTasks(
    String query, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    try {
      final dbService = ObjectBoxService.instance;
      final embeddingService = EmbeddingService.instance;

      if (!dbService.isInitialized) {
        debugPrint('ObjectBox not initialized, falling back to text search');
        return _textSearchTasks(query, startDate: startDate, endDate: endDate);
      }

      if (!embeddingService.isReady) {
        debugPrint('Embedding service not ready, falling back to text search');
        return _textSearchTasks(query, startDate: startDate, endDate: endDate);
      }

      // Get all tasks (with optional date filter)
      var tasks = dbService.getAllCalendarTasks();

      // Apply date filter
      if (startDate != null) {
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        tasks = tasks.where((t) => !t.calendarDate.isBefore(start)).toList();
      }
      if (endDate != null) {
        final end = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
        ).add(const Duration(days: 1));
        tasks = tasks.where((t) => t.calendarDate.isBefore(end)).toList();
      }

      if (tasks.isEmpty) {
        return [];
      }

      // Generate query embedding
      final queryEmbedding = await embeddingService.generateEmbedding(query);

      // Generate embeddings for task content (batch to reduce API calls)
      final taskTexts = tasks.map((t) {
        final text = '${t.taskName} ${t.description ?? ''}';
        return text.trim();
      }).toList();

      final taskEmbeddings = await embeddingService.generateEmbeddings(
        taskTexts,
      );

      // Calculate similarity scores
      final scoredTasks = <Map<String, dynamic>>[];
      for (int i = 0; i < tasks.length; i++) {
        final similarity = _cosineSimilarity(queryEmbedding, taskEmbeddings[i]);
        if (similarity > 0.1) {
          final taskMap = tasks[i].toTaskMap();
          taskMap['_score'] = similarity;
          scoredTasks.add(taskMap);
        }
      }

      // Sort by similarity score descending
      scoredTasks.sort(
        (a, b) => (b['_score'] as double).compareTo(a['_score'] as double),
      );

      // Return top results
      return scoredTasks.take(limit).toList();
    } catch (e) {
      debugPrint('Semantic task search error: $e');
      // Fallback to text search on error
      return _textSearchTasks(query, startDate: startDate, endDate: endDate);
    }
  }

  /// Fallback text-based task search
  List<Map<String, dynamic>> _textSearchTasks(
    String query, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      final dbService = ObjectBoxService.instance;
      if (!dbService.isInitialized) return [];

      final results = dbService.searchTasksByText(
        query,
        startDate: startDate,
        endDate: endDate,
      );

      return results.map((e) => e.toTaskMap()).toList();
    } catch (e) {
      debugPrint('Text task search error: $e');
      return [];
    }
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

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// Legacy text-based search (kept for compatibility)
  List<Map<String, dynamic>> searchTasks(
    String query, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _textSearchTasks(query, startDate: startDate, endDate: endDate);
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
          // Construct text to embed: Message text + Task details
          final buffer = StringBuffer(message.text);

          if (message.tasks != null && message.tasks!.isNotEmpty) {
            buffer.writeln('\nTasks:');
            for (final task in message.tasks!) {
              buffer.writeln('- ${task['task'] ?? 'Untitled'}');
              if (task['Description'] != null &&
                  task['Description'].toString().isNotEmpty) {
                buffer.writeln('  Details: ${task['Description']}');
              }
              if (task['DueDate'] != null) {
                buffer.writeln('  Due: ${task['DueDate']}');
              }
              if (task['priority'] != null) {
                buffer.writeln('  Priority: ${task['priority']}');
              }
            }
          }

          embedding = await embeddingService.generateEmbedding(
            buffer.toString(),
          );
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

  Future<void> refreshBriefingDetails() async {
    _briefingLocation = 'Fetching...';
    _briefingWeather = 'Fetching...';
    _briefingWeatherDetail = '';
    _nextEventInfo = 'Check calendar';
    notifyListeners();

    try {
      final agentTools = GlobalAgentTools(this);

      // 1. Get Location
      if (_mcpClient == null) {
        await _initMcpClient();
      }

      final locationResult = await agentTools.executeTool('get_location', '{}');
      Map<String, dynamic>? locationData;

      // Auto-recovery: if tools are missing or transport is dead, try force restarting MCP
      if (locationResult.contains('Unknown tool') ||
          locationResult.contains('Method not found') ||
          locationResult.contains('Connection closed') ||
          locationResult.contains('Not connected to a transport')) {
        debugPrint(
          '⚠️ MCP transport issue or missing tool. Attempting restart...',
        );
        await _initMcpClient(force: true);
        // Retry once after restart
        final retryResult = await agentTools.executeTool('get_location', '{}');
        if (!retryResult.contains('Error')) {
          locationData = jsonDecode(retryResult);
        }
      } else if (!locationResult.startsWith('Error')) {
        locationData = jsonDecode(locationResult);
      }

      _briefingLocation = locationData?['city'] ?? 'Taipei';

      // 2. Get Weather via Real-Time Tool
      if (locationData != null &&
          locationData['latitude'] != null &&
          locationData['longitude'] != null) {
        final weatherResult = await agentTools.executeTool(
          'get_weather',
          jsonEncode({
            'latitude': locationData['latitude'],
            'longitude': locationData['longitude'],
          }),
        );

        try {
          if (!weatherResult.startsWith('Error')) {
            final weather = jsonDecode(weatherResult);
            final temp = weather['temperature'] ?? '--';
            final status =
                weather['status'] ?? weather['description'] ?? 'Unknown';
            final unit = weather['unit'] ?? '°C';

            _briefingWeather = status.toString();
            _briefingWeatherDetail = '$status · $temp$unit';
          } else {
            _briefingWeather = 'Unknown';
            _briefingWeatherDetail = 'Weather unavailable';
          }
        } catch (e) {
          debugPrint('Failed to parse weather JSON: $e');
        }
      } else {
        // Fallback to web search if no lat/long
        await agentTools.executeTool(
          'web_search',
          jsonEncode({'query': 'current weather in $_briefingLocation'}),
        );
        _briefingWeather = 'Sunny';
        _briefingWeatherDetail = 'Sunny · 25°C';
      }

      // 3. Find Next Event
      final db = ObjectBoxService.instance;
      if (db.isInitialized) {
        final todayTasks = db.getTasksForDate(
          DateTime.now(),
          userEmail: _currentUserEmail,
        );
        if (todayTasks.isNotEmpty) {
          final now = DateTime.now();
          final futureTasks =
              todayTasks.where((t) => t.calendarDate.isAfter(now)).toList()
                ..sort((a, b) => a.calendarDate.compareTo(b.calendarDate));

          if (futureTasks.isNotEmpty) {
            final next = futureTasks.first;
            final time =
                "${next.calendarDate.hour % 12 == 0 ? 12 : next.calendarDate.hour % 12}:${next.calendarDate.minute.toString().padLeft(2, '0')} ${next.calendarDate.hour >= 12 ? 'PM' : 'AM'}";
            _nextEventInfo = "Next: ${next.taskName} @ $time";
          } else {
            _nextEventInfo = "No more events today";
          }
        } else {
          _nextEventInfo = "No events today";
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing briefing: $e');
      _briefingLocation = 'Unavailable';
      _briefingWeather = 'Sunny';
      _briefingWeatherDetail = 'Check Connection';
      _nextEventInfo = 'Sync error';
      notifyListeners();
    }
  }
}
