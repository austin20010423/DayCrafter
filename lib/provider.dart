import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';
import 'package:openai_dart/openai_dart.dart' hide MessageRole;
import 'package:mcp_client/mcp_client.dart' as mcp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models.dart';
import 'database/objectbox_service.dart';
import 'database/objectbox_entities.dart';
import 'services/embedding_service.dart';
import 'services/task_scheduler.dart';
import 'services/local_auth_service.dart';
import 'services/short_term_memory.dart';

// ============================================================================
// MCP Helper Functions
// ============================================================================

/// Detect marker like: [USE_MCP_TOOL: task_and_schedule_planer]
Map<String, String?> detectMcpMarker(String gptText) {
  // Look for the MCP marker format: [USE_MCP_TOOL: tool_name]
  final re = RegExp(r'\[USE_MCP_TOOL:\s*([^\]]+)\]');
  final m = re.firstMatch(gptText);
  if (m == null) {
    debugPrint(
      'ℹ️  No MCP marker detected in GPT response (intent: pure chat)',
    );
    return {'tool': null, 'task': null};
  }

  final tool = m.group(1)!.trim();
  debugPrint('🔍 MCP marker detected! Tool: $tool');

  // Extract task text: look for [INPUT: ...] pattern
  final inputRe = RegExp(r'\[INPUT:\s*([^\]]+)\]');
  final inputMatch = inputRe.firstMatch(gptText);

  String task = '';
  if (inputMatch != null) {
    task = inputMatch.group(1)!.trim();
    debugPrint('📋 Found explicit [INPUT: ...] marker');
  } else {
    // Fallback: extract text after the tool marker
    final after = gptText.substring(m.end).trim();
    task = after.isNotEmpty
        ? after
        : gptText.replaceFirst(m.group(0)!, '').trim();
    debugPrint('📋 Extracted task from context after marker');
  }

  return {'tool': tool, 'task': task};
}

// ============================================================================
/// Calendar view types
enum CalendarViewType { day, week, month }

/// Theme modes
enum AppThemeMode { light, dark, system }

/// Supported locales
enum AppLocale { english, chinese }

/// Navigation items in sidebar
enum NavItem { calendar, agent, dashboard, settings }

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
  int _requestCounter = 0;
  int? _currentRequestId;
  final Set<int> _cancelledRequests = {};

  // API availability state (for fallback to pure chat mode)
  // API availability state (for fallback to pure chat mode)
  bool _isApiAvailable = true;

  // MCP Client Integration
  mcp.Client? _mcpClient;

  // Navigation state
  NavItem _activeNavItem = NavItem.agent;

  // Calendar state
  CalendarViewType _currentCalendarView = CalendarViewType.day;
  DateTime _selectedDate = DateTime.now();

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

  // Memory getters
  ShortTermMemory get shortTermMemory => _shortTermMemory;
  String get memoryContext => _shortTermMemory.getLastNMessagesContext(5);
  int get estimatedMemoryTokens => _shortTermMemory.getEstimatedTokens();

  DayCrafterProvider() {
    _shortTermMemory = ShortTermMemory(maxMessages: 10, maxTokens: 4000);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load theme and locale settings (available before login)
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
      messages: [],
    );
    _projects.add(newProject);
    _activeProjectId = newProject.id;
    await _saveProjects();
    notifyListeners();
  }

  void setActiveProject(String? id) {
    // Save current memory before switching
    if (_activeProjectId != null) {
      _saveMemoryForProject(_activeProjectId!);
    }

    _activeProjectId = id;
    _activeNavItem =
        NavItem.agent; // Switch to agent view when selecting project

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
        debugPrint('✅ Loaded memory for project: $projectId');
      }
    } catch (e) {
      debugPrint('Error loading memory for project: $e');
      _shortTermMemory.clear();
    }
  }

  Future<void> _deleteProjectMemory(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPrefix = _currentUserEmail != null
          ? '${_currentUserEmail}_memory'
          : 'daycrafter_memory';
      await prefs.remove('${userPrefix}_$projectId');
      debugPrint('🗑️ Deleted memory for project: $projectId');
    } catch (e) {
      debugPrint('Error deleting memory for project: $e');
    }
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
        debugPrint('Saving task ${task['task']} with Project ID: $pid');

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
        userEmail: _currentUserEmail,
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
      existing.userEmail = _currentUserEmail;

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
    debugPrint('🛑 User DENIED MCP action.');

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
    debugPrint('Starting AI response with MCP tool support...');

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

      // Build user message with attachments
      String userMessage = userText;
      if (attachments != null && attachments.isNotEmpty) {
        for (final att in attachments) {
          if (_cancelledRequests.contains(requestId)) {
            debugPrint(
              'Request $requestId cancelled before processing attachments',
            );
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

      // Build system prompt using LangChain short-term memory (token-efficient)
      String systemPrompt = _shortTermMemory.getSystemPrompt(
        projectName: activeProject?.name,
      );

      // Inject the full project context
      systemPrompt += projectContext;

      // Add basic MCP context if needed, but keeping it clean as requested
      if (changelog.isNotEmpty) {
        systemPrompt += '\nTask Changelog: $changelog';
      }

      // Add MCP tool requirements
      systemPrompt +=
          '''
You are an autonomous assistant with helping user ${_userName ?? ''} to manage their schedule. 
Only response with 繁體中文 or English.

CRITICAL - MCP TOOL USAGE RULES:
Always use the task_and_schedule_planer tool when the user has STRONG and EXPLICIT intent to:
- Actually CREATE or SCHEDULE tasks on the calendar
- Request you to PLAN or BREAK DOWN a project into tasks
- Ask you to ORGANIZE or RESCHEDULE existing tasks
- Use action words like: "schedule", "plan", "create task", "add to calendar", "break down", "organize my tasks"

DO NOT use the tool for:
- Casual conversation about tasks or plans
- Questions about how to do something
- General advice or suggestions
- When user is just mentioning or discussing tasks without asking to create them
- Hypothetical scenarios ("what if I...", "should I...")

When in doubt, respond conversationally and ask if the user wants you to actually create/schedule the tasks.

AVAILABLE TOOLS:
- task_and_schedule_planer: Use ONLY when user explicitly wants to create, schedule, or organize tasks.

FORMAT TO CALL TOOLS:
If you need to use a tool, your response MUST contain ONLY the following format:
[USE_MCP_TOOL: task_and_schedule_planer]
[INPUT: <what you want the tool to do>]

Project: "${activeProject?.name}"''';

      if (_cancelledRequests.contains(requestId)) {
        debugPrint('Request $requestId cancelled before API call');
        return;
      }

      // Construct a single input string for gpt-5-nano
      // We format the history as a dialogue transcript
      final client = OpenAIClient(apiKey: apiKey);

      final messages = <ChatCompletionMessage>[
        ChatCompletionMessage.system(content: systemPrompt),
      ];

      // Add history
      final history = _shortTermMemory.getMessages();
      for (final msg in history) {
        if (msg['role'] == 'user') {
          messages.add(
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(
                msg['content'] ?? '',
              ),
            ),
          );
        } else {
          messages.add(
            ChatCompletionMessage.assistant(content: msg['content'] ?? ''),
          );
        }
      }

      // Add current user message
      messages.add(
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(userMessage),
        ),
      );

      // Create a placeholder message for the AI response
      final assistantMessageId = DateTime.now().millisecondsSinceEpoch
          .toString();
      final assistantMessage = Message(
        id: assistantMessageId,
        role: MessageRole.model,
        text: '', // Start empty
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

      var aiText = '';
      bool fallbackNeeded = false;

      try {
        final request = CreateChatCompletionRequest(
          model: const ChatCompletionModel.modelId('gpt-5-nano'),
          messages: messages,
          reasoningEffort: ReasoningEffort.low,
        );

        debugPrint('--- Attempting Stream ---');
        final stream = client.createChatCompletionStream(request: request);

        await for (final chunk in stream) {
          if (_cancelledRequests.contains(requestId)) {
            debugPrint('Request $requestId cancelled during stream');
            return;
          }

          final content = chunk.choices?.firstOrNull?.delta?.content ?? "";
          if (content.isNotEmpty) {
            aiText += content;

            // Update the message in place
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

                  final updatedProject = _projects[projectIndex].copyWith(
                    messages: currentMessages,
                  );
                  _projects[projectIndex] = updatedProject;
                  notifyListeners();
                }
              }
            }
          }
        }
      } catch (e) {
        // Check for verification/unsupported value error
        if (e.toString().contains('unsupported_value') ||
            e.toString().contains('verify')) {
          debugPrint(
            "\n[System] Streaming blocked: Verification required. Falling back...",
          );
          fallbackNeeded = true;
        } else {
          debugPrint('Stream Error: $e');
          // For other errors, rethrow to be caught by outer block
          throw e;
        }
      }

      // FALLBACK: Execute a standard request if streaming failed due to verification
      if (fallbackNeeded) {
        if (_cancelledRequests.contains(requestId)) return;

        final response = await client.createChatCompletion(
          request: CreateChatCompletionRequest(
            model: const ChatCompletionModel.modelId('gpt-5-nano'),
            messages: messages,
            reasoningEffort: ReasoningEffort.low,
          ),
        );

        aiText =
            response.choices.first.message.content ??
            "I'm sorry, I couldn't generate a response.";

        // Update the placeholder with full text
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
      }

      // If text is empty after both attempts (and no error thrown), set default
      if (aiText.isEmpty && !fallbackNeeded) {
        aiText = "I'm sorry, I couldn't generate a response.";
        // Final update if needed...
      }

      // Save complete message to storage
      await _saveProjects();

      // Add to memory
      _shortTermMemory.addMessageWithId(
        assistantMessageId,
        aiText,
        'assistant',
      );

      // Save for semantic search
      final finalMsg = Message(
        id: assistantMessageId,
        role: MessageRole.model,
        text: aiText,
        timestamp: DateTime.now(),
      ); // Re-create to ensure clean state

      if (_activeProjectId != null) {
        _saveMessageToObjectBox(finalMsg, _activeProjectId!);
      }

      debugPrint('─' * 60);
      debugPrint('📊 INTENT DETECTION & MCP TRIGGER CHECK');
      debugPrint('─' * 60);
      debugPrint(
        '📊 Memory tokens: ${_shortTermMemory.getEstimatedTokens()}, Messages: ${_shortTermMemory.getMessageCount()}',
      );
      final truncatedQuery = userText.length > 100
          ? '${userText.substring(0, 100)}...'
          : userText;
      debugPrint('User query: "$truncatedQuery"');
      debugPrint('GPT response length: ${aiText.length} chars');

      // Check if GPT wants to use the MCP tool
      final mcpMarker = detectMcpMarker(aiText);

      if (mcpMarker['tool'] != null) {
        if (_isApiAvailable) {
          debugPrint('═' * 60);
          debugPrint('🎯 INTENT CLASSIFIED: TASK PLANNING / SCHEDULING');
          debugPrint('═' * 60);
          debugPrint('✅ MCP tool trigger detected: ${mcpMarker['tool']}');

          // Extract the task input for the MCP tool
          final mcpInput = mcpMarker['task'] ?? userText;
          debugPrint(
            '📝 Task input prepared for MCP: ${mcpInput.length} chars',
          );

          // Request user consent before invoking tool
          debugPrint('✋ Asking user for consent to use MCP tool...');

          await sendMessage(
            "I can help you plan and schedule these tasks using the Calendar Agent. Would you like me to proceed?",
            MessageRole.model,
            isMcpConsent: true,
            mcpInputPending: mcpInput,
          );
          return;
        } else {
          debugPrint(
            '⚠️  MCP tool marker detected but API unavailable - using fallback mode',
          );

          // If MCP failed, remove the markers and send GPT's response anyway
          aiText = aiText
              .replaceAll(RegExp(r'\[USE_MCP_TOOL:.*?\]'), '')
              .replaceAll(RegExp(r'\[INPUT:.*?\]'), '')
              .trim();

          // Update message with cleaned text
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
                _projects[projectIndex] = _projects[projectIndex].copyWith(
                  messages: currentMessages,
                );
                notifyListeners();
                await _saveProjects();
              }
            }
          }
        }
      } else {
        debugPrint('═' * 60);
        debugPrint('💬 INTENT CLASSIFIED: PURE CHAT / CONVERSATION');
        debugPrint('═' * 60);
      }
      debugPrint('');
    } catch (e) {
      debugPrint('AI Error: $e');
      await sendMessage(
        "Failed to connect to AI service. Please check your OpenAI API key.",
        MessageRole.model,
      );
    }
    debugPrint('AI response completed');
  }

  /// Cancel the current in-flight AI request (best-effort).
  void cancelCurrentRequest() {
    if (_currentRequestId != null) {
      _cancelledRequests.add(_currentRequestId!);
      _isLoading = false;
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

  /// Initialize MCP Client connection
  Future<void> _initMcpClient() async {
    if (_mcpClient != null) return;

    try {
      debugPrint('🔌 Initializing MCP Client connection...');

      // Path to python server script

      String serverPath = '';

      // Try relative to project root
      final possiblePaths = [
        '../CrewAI-Driven-Calendar/mcp_server.py',
        'CrewAI-Driven-Calendar/mcp_server.py',
        '/Users/chenchaoshiang/SideProject/AI_Calendar/CrewAI-Driven-Calendar/mcp_server.py',
      ];

      for (final path in possiblePaths) {
        if (await File(path).exists()) {
          serverPath = path;
          break;
        }
      }

      if (serverPath.isEmpty) {
        serverPath = '../CrewAI-Driven-Calendar/mcp_server.py';
        debugPrint(
          '⚠️ Could not find mcp_server.py relatively, using default relative path: $serverPath',
        );
      } else {
        debugPrint('✅ Found MCP server at: $serverPath');
      }

      String pythonCommand = 'python3';

      // Check for virtual environment usage
      final venvPath = File(
        serverPath.replaceAll('mcp_server.py', '.venv/bin/python'),
      );
      if (await venvPath.exists()) {
        pythonCommand = venvPath.path;
        debugPrint('✅ Using virtual environment python: $pythonCommand');
      }

      // Create stdio transport (Standardized JSON-RPC 2.0)
      final transportResult = await mcp.McpClient.createStdioTransport(
        command: pythonCommand,
        arguments: [serverPath],
        environment: {'PYTHONUNBUFFERED': '1'},
      );

      final dynamic result = transportResult;
      // Attempt to access common properties for Result type using dynamic dispatch
      // since the exact API is not exposed or documentation is unavailable.
      var transport;
      try {
        transport = result.success;
      } catch (_) {}
      try {
        transport ??= result.value;
      } catch (_) {}
      try {
        transport ??= result.result;
      } catch (_) {}
      try {
        transport ??= result.data;
      } catch (_) {}

      if (transport == null) {
        // Fallback: maybe it has a `transport` property?
        try {
          transport ??= result.transport;
        } catch (_) {}
      }

      if (transport == null) {
        debugPrint('⚠️ Could not unwrap Result type: ${result.runtimeType}');
        // If it was an error, try to print it
        try {
          debugPrint('Error content: ${result.error}');
        } catch (_) {}
        try {
          debugPrint('Failure content: ${result.failure}');
        } catch (_) {}
        throw Exception("Unknown Result API");
      }

      _mcpClient = mcp.McpClient.createClient(
        mcp.McpClientConfig(name: "DayCrafterClient", version: "1.0.0"),
      );

      await _mcpClient!.connect(transport);
      debugPrint('✅ Connected to MCP Server!');

      // List tools to verify
      final tools = await _mcpClient!.listTools();
      debugPrint(
        '🛠️ Discovered ${tools.length} MCP tools: ${tools.map((t) => t.name).join(", ")}',
      );
      _isApiAvailable = true;
    } catch (e) {
      debugPrint('❌ Failed to initialize MCP client: $e');
      _isApiAvailable = false;
    }
  }

  Future<List<Map<String, dynamic>>?> _getTasks(String userText) async {
    debugPrint('Starting MCP task API call...');

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
      final result = await _mcpClient!.callTool('task_and_schedule_planer', {
        'topic': userText,
      });

      // Extract text content from result
      String rawResult = '';
      if (result.content.isNotEmpty) {
        // Assuming the first content block is the text result
        final block = result.content.first;
        if (block is mcp.TextContent) {
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
      try {
        final parsed = jsonDecode(result);
        if (parsed is List) {
          return parsed.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint('Failed to parse MCP result as JSON: $e');
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
      '🔎 DEBUG check: User has ${allTasks.length} total tasks remaining in DB after deletion.',
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
