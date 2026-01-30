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
    debugPrint('ℹ️  No MCP marker detected in GPT response (intent: pure chat)');
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
    task = after.isNotEmpty ? after : gptText.replaceFirst(m.group(0)!, '').trim();
    debugPrint('📋 Extracted task from context after marker');
  }
  
  debugPrint('📋 MCP task input extracted: ${task.length} chars');
  return {'tool': tool, 'task': task};
}

/// Call MCP invoke endpoint
Future<Map<String, dynamic>> callMcpInvoke({
  required String baseUrl, // e.g. "http://127.0.0.1:8000"
  required String tool,
  required String taskText,
  String? bearerToken,
  Duration timeout = const Duration(seconds: 300),
}) async {
  final url = Uri.parse('$baseUrl/mcp/invoke');
  debugPrint('🚀 Calling MCP server: $url');
  debugPrint('   Tool: $tool, Timeout: ${timeout.inSeconds}s');

  final payload = {
    'inputs': {
      'topic': taskText,
      'tool': tool,
    }
  };

  final headers = <String, String>{
    'Content-Type': 'application/json',
    if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
  };

  try {
    final response = await http
        .post(url, headers: headers, body: jsonEncode(payload))
        .timeout(timeout);

    debugPrint('📡 MCP response received: Status ${response.statusCode}');

    if (response.statusCode >= 400) {
      debugPrint('❌ MCP call failed: ${response.statusCode}');
      throw Exception('MCP call failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    debugPrint('✅ MCP response parsed successfully');

    // Prefer MCP-style outputs.content.result, fallback to top-level result
    final result = (data['outputs']?['content']?['result']) ?? data['result'] ?? data;
    debugPrint('📦 MCP result extracted, type: ${result.runtimeType}');
    return {'id': data['id'], 'result': result};
  } catch (e) {
    debugPrint('❌ MCP call error: $e');
    rethrow;
  }
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
  bool _isApiAvailable = true;
  final String _mcpBaseUrl = 'http://127.0.0.1:8000'; // MCP: task_and_schedule_planer
  final String _mcpTool = 'task_and_schedule_planer';

  // Navigation state
  NavItem _activeNavItem = NavItem.agent;

  // Calendar state
  CalendarViewType _currentCalendarView = CalendarViewType.day;
  DateTime _selectedDate = DateTime.now();

  // Theme and localization state
  AppThemeMode _themeMode = AppThemeMode.light;
  AppLocale _locale = AppLocale.english;

  // Token-efficient task changelog per project (stores compact summary instead of full JSON)
  // Format: "v1: Created 5 tasks (2 high, 2 med, 1 low) | v2: Adjusted due dates | v3: Added 2 tasks"
  Map<String, String> _taskChangelogs = {};

  // Store raw MCP API responses per project so the agent/system can remember them
  // Format: { projectId: [ { 'id': '<mcp-id>', 'result': <raw-result> }, ... ] }
  Map<String, List<Map<String, dynamic>>> _mcpResponses = {};

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
    _taskChangelogs = {};
    _shortTermMemory.clear(); // Clear memory on logout
    notifyListeners();
  }

  /// Get list of registered accounts for account selector
  Future<List<Map<String, String>>> getRegisteredAccounts() async {
    return _authService.getRegisteredAccounts();
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

    // Load changelogs for token-efficient LLM context
    await _loadChangelogs();

    // Load stored MCP responses so agent/system memory includes API outputs
    await _loadMcpResponses();

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

  Future<void> sendMessage(String text, MessageRole role,
      {List<Map<String, String>>? attachments}) async {
    if (_activeProjectId == null) return;

    final projectIndex = _projects.indexWhere((p) => p.id == _activeProjectId);
    if (projectIndex == -1) return;

    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: role,
      text: text,
      attachments: attachments,
      timestamp: DateTime.now(),
    );

    final updatedProject = _projects[projectIndex].copyWith(
      messages: [..._projects[projectIndex].messages, newMessage],
    );

    _projects[projectIndex] = updatedProject;
    await _saveProjects();

    // Add to LangChain short-term memory (token-efficient)
    _shortTermMemory.addMessageWithId(
      newMessage.id,
      text,
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
      await _getAiResponse(text, attachments: attachments, requestId: requestId);

      // If this request was cancelled, don't overwrite loading state again
      if (!_cancelledRequests.contains(requestId)) {
        _isLoading = false;
        notifyListeners();
      }
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

      final openAI = OpenAI.instance.build(
        token: apiKey,
        baseOption: HttpSetup(
          receiveTimeout: const Duration(seconds: 30),
          connectTimeout: const Duration(seconds: 30),
        ),
      );

      // Build user message with attachments
      String userMessage = userText;
      if (attachments != null && attachments.isNotEmpty) {
        for (final att in attachments) {
          if (_cancelledRequests.contains(requestId)) {
            debugPrint('Request $requestId cancelled before processing attachments');
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
      final projectId = _activeProjectId ?? '';
      final changelog = _taskChangelogs[projectId] ?? '';

      // Build system prompt using LangChain short-term memory (token-efficient)
      String systemPrompt = _shortTermMemory.getSystemPrompt(
        projectName: activeProject?.name,
      );
      
      // Add MCP tool requirements
      systemPrompt += '''

⚠️  CRITICAL INSTRUCTION - READ CAREFULLY:
You MUST use the MCP tool "task_and_schedule_planer" for ALL of these requests:
- "give me a plan" → USE MCP TOOL
- "schedule this" → USE MCP TOOL
- "create tasks" → USE MCP TOOL
- "organize this" → USE MCP TOOL
- "plan this assignment" → USE MCP TOOL
- "break this down" → USE MCP TOOL
- "modify tasks" → USE MCP TOOL (if asking to reorganize/refine existing plans)
- ANY task-related request → USE MCP TOOL

REQUIRED RESPONSE FORMAT:
Always respond with BOTH:
1. Your analysis/explanation (reference previous context if relevant)
2. The MCP tool markers (MUST HAVE):

[USE_MCP_TOOL: task_and_schedule_planer]
[INPUT: <specific details about what user wants>]

Project: "${activeProject?.name}"''';

      if (changelog.isNotEmpty) {
        systemPrompt += '\nTask Changelog: $changelog';
      }

      systemPrompt += '''

IMPORTANT BEHAVIORS:
1. Reference previous messages and tasks when relevant
2. Remember all previous user requests in this thread
3. Build upon previous plans rather than starting from scratch
4. Use the MCP tool EVERY TIME for planning/scheduling/task requests!
5. Include context from chat history in your responses''';

      if (_cancelledRequests.contains(requestId)) {
        debugPrint('Request $requestId cancelled before API call');
        return;
      }

      // Build full conversation history including chat messages and API responses
      final messages = <Map<String, dynamic>>[];
      messages.add({"role": "system", "content": systemPrompt});

      // Use LangChain short-term memory for token-efficient message history
      messages.addAll(_shortTermMemory.getMessages());

      // Add current user message
      messages.add({"role": "user", "content": userMessage});

      final request = ChatCompleteText(
        model: GptTurboChatModel(),
        messages: messages,
        maxToken: 1000,
      );

      final response = await openAI.onChatCompletion(request: request);

      var aiText = response?.choices.first.message?.content ??
          "I'm sorry, I couldn't generate a response.";

      debugPrint('─' * 60);
      debugPrint('📊 INTENT DETECTION & MCP TRIGGER CHECK');
      debugPrint('─' * 60);
      debugPrint('📊 Memory tokens: ${_shortTermMemory.getEstimatedTokens()}, Messages: ${_shortTermMemory.getMessageCount()}');
      final truncatedQuery = userText.length > 100 ? '${userText.substring(0, 100)}...' : userText;
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
          debugPrint('📝 Task input prepared for MCP: ${mcpInput.length} chars');
          
          // Call the MCP server
          debugPrint('\n🔗 INVOKING MCP SERVER...');
          final tasks = await _getTasks(mcpInput);
          
          if (tasks != null && tasks.isNotEmpty) {
            debugPrint('\n✅ SUCCESS: MCP returned ${tasks.length} tasks');
            debugPrint('═' * 60);
            // Task message was already added by _getTasks()
            // Don't send the GPT message with MCP markers
            return;
          }
          
          debugPrint('⚠️  MCP returned empty or null results, falling back to GPT response');
        } else {
          debugPrint('⚠️  MCP tool marker detected but API unavailable - using fallback mode');
        }
        
        // If MCP failed, remove the markers and send GPT's response anyway
        aiText = aiText.replaceAll(RegExp(r'\[USE_MCP_TOOL:.*?\]'), '')
                       .replaceAll(RegExp(r'\[INPUT:.*?\]'), '')
                       .trim();
      } else {
        debugPrint('═' * 60);
        debugPrint('💬 INTENT CLASSIFIED: PURE CHAT / CONVERSATION');
        debugPrint('═' * 60);
      }
      debugPrint('');

      if (_cancelledRequests.contains(requestId)) {
        debugPrint('Request $requestId cancelled after API call');
        return;
      }

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

  Future<List<Map<String, dynamic>>?> _getTasks(String userText) async {
    debugPrint('Starting MCP task API call...');
    try {
      // Call the MCP endpoint using the new /mcp/invoke pattern
      final invokeResult = await callMcpInvoke(
        baseUrl: _mcpBaseUrl,
        tool: _mcpTool,
        taskText: userText,
        timeout: const Duration(seconds: 300),
      );

      // Keep raw result for system memory and parsing
      final rawResult = invokeResult['result'];

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

      // Create message with task cards
      final taskMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.model,
        text: 'Here are the planned tasks:',
        timestamp: DateTime.now(),
        tasks: tasks,
      );

      final projectIndex = _projects.indexWhere(
        (p) => p.id == _activeProjectId,
      );
      if (projectIndex != -1) {
        var messagesToAdd = [taskMessage];

        // Get previous tasks from this project for comparison
        final previousTasks = _getPreviousProjectTasks(_projects[projectIndex]);
        
        // Get ALL tasks ever planned in this project (for agent context)
        final allProjectTasks = _getAllProjectTasks(_projects[projectIndex]);
        
        // Generate dynamic agent response about what changed
        if (previousTasks.isNotEmpty) {
          final dynamicResponse = await _generateDynamicChangeResponse(
            previousTasks: previousTasks,
            newTasks: tasks,
            allProjectTasks: allProjectTasks,
            projectMessages: _projects[projectIndex].messages,
            userRequest: userText,
          );
          
          if (dynamicResponse.isNotEmpty) {
            debugPrint('🤖 Agent generated dynamic response: ${dynamicResponse.length} chars');
            
            // Create agent response message
            final responseMessage = Message(
              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
              role: MessageRole.model,
              text: dynamicResponse,
              timestamp: DateTime.now().add(const Duration(milliseconds: 1)),
            );
            
            messagesToAdd.add(responseMessage);
          }
        }

        final updatedProject = _projects[projectIndex].copyWith(
          messages: [..._projects[projectIndex].messages, ...messagesToAdd],
        );
        _projects[projectIndex] = updatedProject;
        await _saveProjects();

        // Persist each new message into ObjectBox so embeddings/search include them
        for (final msg in messagesToAdd) {
          try {
            await _saveMessageToObjectBox(msg, _activeProjectId!);
          } catch (e) {
            debugPrint('Failed to save task message to ObjectBox: $e');
          }
        }

        // Save raw MCP response into system memory store for the project
          try {
          final pid = _activeProjectId ?? _projects[projectIndex].id;
          _mcpResponses.putIfAbsent(pid, () => []);
          _mcpResponses[pid]!.add({
            'id': invokeResult['id'],
            'result': rawResult,
            'timestamp': DateTime.now().toIso8601String(),
          });
          await _saveMcpResponses();
        } catch (e) {
          debugPrint('Failed to persist MCP raw response: $e');
        }

        // Add MCP task response to short-term memory so agent remembers planned tasks
        try {
          final taskSummary = _buildTaskSummaryForMemory(tasks);
          _shortTermMemory.addMessage(
            'MCP Task Planning Result:\n$taskSummary',
            'assistant',
          );
          debugPrint('✅ Added ${tasks.length} planned tasks to short-term memory');
        } catch (e) {
          debugPrint('Failed to add MCP response to memory: $e');
        }

        // Update token-efficient changelog
        _updateTaskChangelog(_activeProjectId!, tasks);

        notifyListeners();
      }

      debugPrint('✅ MCP task API completed with ${tasks.length} tasks');
      return tasks;
    } catch (e) {
      debugPrint('❌ MCP task API Error: $e');
      // Mark API as unavailable and fall back to pure chat mode
      _isApiAvailable = false;
      
      debugPrint('🔴 MCP API is unavailable. Falling back to pure chat mode.');
      return null; // Return null to skip task creation and proceed to pure chat
    }
  }

  /// Build token-efficient conversation history with compression
  /// Convert Dart MessageRole enum to OpenAI-compatible role string
  String _convertRoleToOpenAI(MessageRole role) {
    return role == MessageRole.user ? 'user' : 'assistant';
  }

  List<Map<String, String>> _buildCompressedConversationHistory(
    List<Message> allMessages, {
    int maxRecentMessages = 3,
  }) {
    if (allMessages.isEmpty) return [];

    final messages = <Map<String, String>>[];
    
    // Keep recent messages in full, compress older ones
    int recentCount = 0;
    for (int i = allMessages.length - 1; i >= 0; i--) {
      final msg = allMessages[i];
      
      // Include task result messages in the history (but summarized)
      if (msg.tasks != null && msg.tasks!.isNotEmpty) {
        // Summarize task message for context
        final taskSummary = msg.tasks!.map((t) => t['TaskName'] ?? 'Task').join(', ');
        messages.insert(0, {
          'role': 'assistant',
          'content': 'Created tasks: $taskSummary',
        });
        continue;
      }
      
      // Skip empty messages
      if (msg.text.isEmpty) continue;
      
      if (recentCount < maxRecentMessages) {
        // Keep recent messages as-is, but convert role using helper
        final role = _convertRoleToOpenAI(msg.role);
        messages.insert(0, {
          'role': role,
          'content': msg.text,
        });
        recentCount++;
      } else {
        // Compress older messages
        if (i < allMessages.length - maxRecentMessages) {
          final summary = _summarizeOldMessage(msg);
          if (summary.isNotEmpty) {
            messages.insert(0, {
              'role': 'system',
              'content': '(Previous context: $summary)',
            });
          }
          break; // Only keep compressed summary of earlier context
        }
      }
    }
    
    return messages;
  }

  /// Create concise summary of old message
  String _summarizeOldMessage(Message msg) {
    final text = msg.text;
    if (text.length < 50) return text;
    
    // Extract first 50 chars and add ellipsis
    return '${text.substring(0, 50)}...';
  }

  /// Convert priority number to label
  String _getPriorityLabel(dynamic priority) {
    final p = priority is int ? priority : int.tryParse(priority?.toString() ?? '3') ?? 3;
    switch (p) {
      case 1: return 'High';
      case 2: return 'Medium';
      default: return 'Low';
    }
  }

  /// Generate dynamic agent response about changes using GPT
  Future<String> _generateDynamicChangeResponse({
    required List<Map<String, dynamic>> previousTasks,
    required List<Map<String, dynamic>> newTasks,
    required List<Map<String, dynamic>> allProjectTasks,
    required List<Message> projectMessages,
    required String userRequest,
  }) async {
    try {
      // Load API key
      String apiKey;
      try {
        if (!dotenv.isInitialized) {
          await dotenv.load(fileName: ".env");
        }
        apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_OPENAI_API_KEY';
      } catch (e) {
        debugPrint('Dotenv error: $e');
        apiKey = 'YOUR_OPENAI_API_KEY';
      }

      final openAI = OpenAI.instance.build(
        token: apiKey,
        baseOption: HttpSetup(
          receiveTimeout: const Duration(seconds: 30),
          connectTimeout: const Duration(seconds: 30),
        ),
      );

      // Build token-efficient conversation history
      final conversationHistory = _buildCompressedConversationHistory(projectMessages);
      
      // Build task comparison context with full details
      final prevNames = previousTasks.map((t) => t['TaskName'] as String?).toSet();
      final newNames = newTasks.map((t) => t['TaskName'] as String?).toSet();
      final added = newNames.difference(prevNames);
      final removed = prevNames.difference(newNames);
      
      // Format all project tasks for reference
      String allTasksContext = '';
      if (allProjectTasks.isNotEmpty) {
        allTasksContext = '\n📋 ALL TASKS IN THIS PROJECT:\n';
        for (int i = 0; i < allProjectTasks.length; i++) {
          final task = allProjectTasks[i];
          final name = task['TaskName'] ?? 'Unnamed';
          final priority = _getPriorityLabel(task['priority']);
          final desc = task['Description'] ?? '';
          final status = task['Status'] ?? 'Planned';
          
          allTasksContext += '${i + 1}. $name\n';
          allTasksContext += '   Priority: $priority | Status: $status\n';
          if (desc.isNotEmpty) {
            allTasksContext += '   Description: ${desc.length > 80 ? desc.substring(0, 80) + '...' : desc}\n';
          }
        }
      }
      
      // Build detailed task information for context
      String taskDetails = 'New Tasks Created:\n';
      for (final task in newTasks) {
        final name = task['TaskName'] ?? 'Unnamed';
        final priority = _getPriorityLabel(task['priority']);
        final desc = task['Description'] ?? '';
        taskDetails += '  • $name (Priority: $priority)';
        if (desc.isNotEmpty && desc.length < 100) {
          taskDetails += ' - $desc';
        }
        taskDetails += '\n';
      }
      
      String changeContext = 'Previous task count: ${previousTasks.length}\n';
      changeContext += 'New task count: ${newTasks.length}\n';
      changeContext += 'Total tasks in project: ${allProjectTasks.length}\n';
      changeContext += 'Added tasks: ${added.isEmpty ? "none" : added.join(", ")}\n';
      changeContext += 'Removed tasks: ${removed.isEmpty ? "none" : removed.join(", ")}\n\n';
      changeContext += taskDetails;
      changeContext += allTasksContext;

      final systemPrompt = '''You are an intelligent project assistant with complete access to the project's entire task planning history.

Project: "${activeProject?.name}"

You have full access to:
- The complete task list that was just created
- ALL previously planned tasks in this conversation thread
- Previous task versions and their modifications
- The user's specific request
- The entire conversation history

Your role:
1. Acknowledge what new tasks were created
2. Relate them to existing tasks if relevant
3. Provide thoughtful commentary about the plan
4. Help users refine tasks through natural language

KEY CAPABILITY: You can discuss ANY task ever mentioned in this project. Users can ask you to:
- Modify task priorities or descriptions
- Change task status or dates
- Add dependencies between tasks
- Remove or consolidate tasks
- Explain why certain tasks are important

When discussing tasks:
1. Reference them by their exact names
2. Show understanding of dependencies and relationships
3. Be practical and implementation-focused
4. Suggest improvements when appropriate

IMPORTANT:
1. Reference specific tasks by name when discussing changes
2. Be concise but insightful - 2-3 sentences typically
3. Focus on the meaning and impact of changes
4. Reference the user's intent and acknowledge it
5. Be encouraging and supportive
6. Each response must feel natural and context-specific
7. Do NOT use markdown, bullet points, or structured lists

User's specific request: "$userRequest"

Task Information:
$changeContext

Respond naturally as if discussing the plan update with the project team.''';

      // Build message list with conversation history
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        ...conversationHistory,
        {
          'role': 'user',
          'content': 'Analyze the new tasks that were created and provide feedback on the updated plan. What are the key changes and what do you think about them?'
        }
      ];

      debugPrint('🧠 Generating dynamic response with ${messages.length} messages (token-efficient)');

      final request = ChatCompleteText(
        model: GptTurboChatModel(),
        messages: messages,
        maxToken: 300, // Shorter response for change commentary
      );

      final response = await openAI.onChatCompletion(request: request);
      final dynamicText = response?.choices.first.message?.content ?? '';

      return dynamicText.trim();
    } catch (e) {
      debugPrint('❌ Error generating dynamic response: $e');
      return ''; // Return empty to skip adding dynamic response
    }
  }

  /// Get all tasks ever planned in this project (from all message history)
  List<Map<String, dynamic>> _getAllProjectTasks(Project project) {
    final allTasks = <String, Map<String, dynamic>>{};
    
    // Iterate through all messages and collect all task references
    for (final msg in project.messages) {
      if (msg.tasks != null && msg.tasks!.isNotEmpty) {
        for (final task in msg.tasks!) {
          final taskName = task['TaskName'] as String?;
          if (taskName != null) {
            // Keep the latest version of each task (tasks are added chronologically)
            allTasks[taskName] = task;
          }
        }
      }
    }
    
    return allTasks.values.toList();
  }

  /// Get previous tasks from project history
  List<Map<String, dynamic>> _getPreviousProjectTasks(Project project) {
    // Find the last message that has tasks (going backwards)
    for (int i = project.messages.length - 1; i >= 0; i--) {
      final msg = project.messages[i];
      if (msg.tasks != null && msg.tasks!.isNotEmpty) {
        return msg.tasks!;
      }
    }
    return [];
  }

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

  /// Build a concise task summary for short-term memory
  String _buildTaskSummaryForMemory(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) return '(no tasks)';
    
    final taskList = tasks
        .take(5) // Limit to first 5 tasks for token efficiency
        .map((t) {
          final name = t['TaskName']?.toString() ?? 'Task';
          final priority = t['priority'] ?? 3;
          final priorityLabel = priority == 1 ? '🔴' : priority == 2 ? '🟡' : '🟢';
          return '• $priorityLabel $name';
        })
        .join('\n');
    
    final moreCount = tasks.length > 5 ? '\n... and ${tasks.length - 5} more tasks' : '';
    return '$taskList$moreCount';
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

  /// Persist raw MCP responses so the agent can recall API outputs later
  Future<void> _saveMcpResponses() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserEmail != null
        ? '${_currentUserEmail}_mcp_responses'
        : 'daycrafter_mcp_responses';
    try {
      await prefs.setString(key, jsonEncode(_mcpResponses));
    } catch (e) {
      debugPrint('Failed to save MCP responses: $e');
    }
  }

  Future<void> _loadMcpResponses() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserEmail != null
        ? '${_currentUserEmail}_mcp_responses'
        : 'daycrafter_mcp_responses';
    try {
      final data = prefs.getString(key);
      if (data != null) {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        _mcpResponses = decoded.map((k, v) => MapEntry(
            k, (v as List).map((e) => Map<String, dynamic>.from(e)).toList()));
      }
    } catch (e) {
      debugPrint('Failed to load MCP responses: $e');
      _mcpResponses = {};
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
    _projects.removeWhere((p) => p.id == projectId);

    // Clean up changelog for this project
    _taskChangelogs.remove(projectId);
    await _saveChangelogs();

    // CRM-style cascade delete: removes project, messages, and tasks from DB
    ObjectBoxService.instance.deleteProjectByUuid(projectId);

    // Switch to another project if deleted the active one
    if (_activeProjectId == projectId) {
      _activeProjectId = _projects.isNotEmpty ? _projects.first.id : null;
    }

    await _saveProjects();

    // Debug verification
    final db = ObjectBoxService.instance;
    final allTasks = db.getAllCalendarTasks(userEmail: _currentUserEmail);
    debugPrint(
      '🔎 DEBUG check: User has ${allTasks.length} total tasks remaining in DB after deletion.',
    );

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
