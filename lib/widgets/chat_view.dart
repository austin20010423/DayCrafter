import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../provider.dart';
import '../styles.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

enum ViewMode { defaultMode, upload, recording }

class _ChatViewState extends State<ChatView> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  ViewMode _viewMode = ViewMode.defaultMode;
  String? _attachedFile;
  int _timerSeconds = 0;
  Timer? _timer;

  // Sidebar state
  bool _isSidebarOpen = false;
  List<Map<String, dynamic>>? _sidebarTasks;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startRecording() {
    setState(() {
      _viewMode = ViewMode.recording;
      _timerSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _timerSeconds++);
    });
  }

  void _stopRecording(bool save) {
    _timer?.cancel();
    setState(() {
      if (save) _attachedFile = "Audio Recording.wav";
      _viewMode = ViewMode.defaultMode;
    });
  }

  void _handleSubmit() {
    final text = _inputController.text.trim();
    if (text.isEmpty && _attachedFile == null) return;

    final provider = context.read<DayCrafterProvider>();
    if (provider.isLoading) return;

    String content = text;
    if (text.isEmpty && _attachedFile != null) {
      content = "Attached: $_attachedFile";
    }

    provider.sendMessage(content, MessageRole.user);
    _inputController.clear();
    setState(() {
      _attachedFile = null;
      _viewMode = ViewMode.defaultMode;
    });
    _scrollToBottom();
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final project = provider.activeProject;
    final userName = provider.userName ?? 'User';
    final isInitialState =
        (project?.messages.length ?? 0) <= 1 && !provider.isLoading;

    if (project == null) return const SizedBox.shrink();

    return Stack(
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: GridDotPainter(dotColor: AppStyles.mTextSecondary),
        ),
        _buildContent(project, userName, isInitialState, provider.isLoading),
        // Sidebar overlay
        if (_isSidebarOpen) ...[
          // Dark overlay to dim background
          GestureDetector(
            onTap: () => setState(() => _isSidebarOpen = false),
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),
          // Sidebar
          _buildTaskSidebar(),
        ],
      ],
    );
  }

  Widget _buildContent(
    Project project,
    String userName,
    bool isInitialState,
    bool isLoading,
  ) {
    switch (_viewMode) {
      case ViewMode.recording:
        return _buildRecordingView();
      case ViewMode.upload:
        return _buildUploadView();
      case ViewMode.defaultMode:
        return _buildDefaultView(project, userName, isInitialState, isLoading);
    }
  }

  Widget _buildRecordingView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: AppStyles.mSurface,
          borderRadius: AppStyles.bRadiusLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () => _stopRecording(false),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.bRadiusMedium,
                ),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 48),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _formatTime(_timerSeconds),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: AppStyles.mTextPrimary,
              ),
            ),
            const SizedBox(height: 64),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CircularIconButton(icon: LucideIcons.pause, onTap: () {}),
                const SizedBox(width: 32),
                _CircularIconButton(
                  icon: LucideIcons.check,
                  onTap: () => _stopRecording(true),
                  backgroundColor: AppStyles.mPrimary,
                  iconColor: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadView() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(64),
        decoration: BoxDecoration(
          color: AppStyles.mSurface,
          borderRadius: AppStyles.bRadiusLarge,
          border: Border.all(color: AppStyles.mBackground, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Let me help you!',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppStyles.mTextPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 6,
              decoration: BoxDecoration(
                color: AppStyles.mSecondary,
                borderRadius: AppStyles.bRadiusSmall,
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Add anything here',
              style: TextStyle(
                fontSize: 20,
                fontStyle: FontStyle.italic,
                color: AppStyles.mTextSecondary,
              ),
            ),
            const SizedBox(height: 56),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CircularIconButton(
                  icon: LucideIcons.uploadCloud,
                  onTap: () {
                    setState(() {
                      _attachedFile = "New Document.pdf";
                      _viewMode = ViewMode.defaultMode;
                    });
                  },
                ),
                const SizedBox(width: 32),
                _CircularIconButton(
                  icon: LucideIcons.mic2,
                  onTap: _startRecording,
                ),
                const SizedBox(width: 32),
                _CircularIconButton(icon: LucideIcons.fileText, onTap: () {}),
              ],
            ),
            const SizedBox(height: 64),
            TextButton(
              onPressed: () => setState(() => _viewMode = ViewMode.defaultMode),
              child: Text(
                'Go back',
                style: TextStyle(color: AppStyles.mTextSecondary, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultView(
    Project project,
    String userName,
    bool isInitialState,
    bool isLoading,
  ) {
    if (isInitialState) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()},',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.mTextSecondary,
                    letterSpacing: -1.5,
                  ),
                ),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.mPrimary,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 64),
                _buildInputBox(true),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            itemCount: project.messages.length + (isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == project.messages.length) {
                return _buildLoadingBubble();
              }
              final msg = project.messages[index];
              return _buildMessageBubble(msg);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: _buildInputBox(false),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Message msg) {
    final isUser = msg.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              decoration: BoxDecoration(
                color: AppStyles.mBackground,
                borderRadius: AppStyles.bRadiusSmall,
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                LucideIcons.sparkles,
                size: 20,
                color: AppStyles.mPrimary,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isUser ? AppStyles.mPrimary : AppStyles.mSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isUser ? 24 : 8),
                  bottomRight: Radius.circular(isUser ? 8 : 24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use markdown for AI responses, plain text for user messages
                  if (isUser)
                    Text(
                      msg.text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: msg.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: AppStyles.mTextPrimary,
                          fontSize: 15,
                          height: 1.6,
                        ),
                        h1: TextStyle(
                          color: AppStyles.mTextPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: AppStyles.mTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: AppStyles.mTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        strong: TextStyle(
                          color: AppStyles.mTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: AppStyles.mTextPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                        code: TextStyle(
                          backgroundColor: AppStyles.mBackground,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: AppStyles.mBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        listBullet: TextStyle(color: AppStyles.mTextPrimary),
                      ),
                      selectable: true,
                    ),
                  if (msg.tasks != null && msg.tasks!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTaskCards(msg.tasks!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCards(List<Map<String, dynamic>> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2-column grid layout
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tasks.map((task) {
            final priorityColor = AppStyles.getPriorityColor(task['priority']);

            return Container(
              width: 200,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.15),
                borderRadius: AppStyles.bRadiusMedium,
                border: Border.all(
                  color: priorityColor.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task name
                  Text(
                    task['task'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.mTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Due Date
                  _buildInfoRow('Due', task['DueDate'] ?? '-'),
                  const SizedBox(height: 4),
                  // Start Date
                  _buildInfoRow('Start', task['dateOnCalendar'] ?? '-'),
                  const SizedBox(height: 4),
                  // Priority with colored badge
                  Row(
                    children: [
                      Text(
                        'Priority: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppStyles.mTextSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getPriorityLabel(task['priority']),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Click here to edit button
        GestureDetector(
          onTap: () {
            setState(() {
              _sidebarTasks = tasks;
              _isSidebarOpen = true;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppStyles.mPrimary.withValues(alpha: 0.1),
              borderRadius: AppStyles.bRadiusMedium,
              border: Border.all(
                color: AppStyles.mPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.edit3, size: 16, color: AppStyles.mPrimary),
                const SizedBox(width: 8),
                Text(
                  'Click here to edit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.mPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: AppStyles.mTextSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 11, color: AppStyles.mTextPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getPriorityLabel(dynamic priority) {
    final int p = priority is int
        ? priority
        : int.tryParse(priority?.toString() ?? '3') ?? 3;
    switch (p) {
      case 1:
        return 'High';
      case 2:
        return 'Medium';
      default:
        return 'Low';
    }
  }

  Widget _buildTaskSidebar() {
    final tasks = _sidebarTasks ?? [];

    // Sort tasks by priority (1 = highest priority first)
    final sortedTasks = List<Map<String, dynamic>>.from(tasks)
      ..sort((a, b) {
        final pA = a['priority'] is int
            ? a['priority']
            : int.tryParse(a['priority']?.toString() ?? '3') ?? 3;
        final pB = b['priority'] is int
            ? b['priority']
            : int.tryParse(b['priority']?.toString() ?? '3') ?? 3;
        return pA.compareTo(pB);
      });

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.mSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppStyles.mPrimary),
              child: Row(
                children: [
                  Icon(LucideIcons.listTodo, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Task Details',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _isSidebarOpen = false),
                    icon: Icon(LucideIcons.x, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Task list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedTasks.length,
                itemBuilder: (context, index) {
                  final task = sortedTasks[index];
                  return _buildDetailedTaskCard(task);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedTaskCard(Map<String, dynamic> task) {
    final priorityColor = AppStyles.getPriorityColor(task['priority']);
    final hasDetails =
        (task['Description'] != null &&
            task['Description'].toString().isNotEmpty) ||
        (task['links'] != null && task['links'].toString().isNotEmpty);

    return _ExpandableTaskCard(
      task: task,
      priorityColor: priorityColor,
      priorityLabel: _getPriorityLabel(task['priority']),
      hasDetails: hasDetails,
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppStyles.mBackground,
              borderRadius: AppStyles.bRadiusSmall,
            ),
            child: Icon(
              LucideIcons.sparkles,
              size: 20,
              color: AppStyles.mPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppStyles.mSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(8),
                  bottomRight: const Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildThinkingAnimationContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingAnimationContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Agent thinking',
          style: TextStyle(
            color: AppStyles.mTextPrimary,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(width: 12),
        _BouncingDots(color: AppStyles.mPrimary),
      ],
    );
  }

  Widget _buildInputBox(bool isInitial) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppStyles.mSurface,
        borderRadius: AppStyles.bRadiusLarge,
        border: Border.all(color: AppStyles.mBackground, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 50,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _inputController,
            maxLines: isInitial ? 2 : 4,
            minLines: isInitial ? 2 : 1,
            style: TextStyle(fontSize: 18, color: AppStyles.mTextPrimary),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _handleSubmit(),
            onChanged: (_) =>
                setState(() {}), // Update button state on text change
            decoration: InputDecoration(
              hintText: 'Type a meeting note...',
              hintStyle: TextStyle(
                color: AppStyles.mTextSecondary.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _InputActionButton(
                    icon: LucideIcons.paperclip,
                    label: 'Attach',
                    onTap: () => setState(() => _viewMode = ViewMode.upload),
                  ),
                  if (_attachedFile != null) ...[
                    const SizedBox(width: 16),
                    _AttachedFileTag(
                      fileName: _attachedFile!,
                      onRemove: () => setState(() => _attachedFile = null),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  _IconButton(icon: LucideIcons.mic, onTap: _startRecording),
                  const SizedBox(width: 16),
                  _IconButton(
                    icon: LucideIcons.send,
                    onTap: _handleSubmit,
                    isPrimary: true,
                    enabled:
                        _inputController.text.isNotEmpty ||
                        _attachedFile != null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const _CircularIconButton({
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color:
              backgroundColor ?? AppStyles.mBackground.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          boxShadow: backgroundColor != null
              ? [
                  BoxShadow(
                    color: backgroundColor!.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: iconColor ?? AppStyles.mTextPrimary, size: 32),
      ),
    );
  }
}

class _InputActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InputActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppStyles.bRadiusMedium,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppStyles.mBackground.withValues(alpha: 0.4),
          borderRadius: AppStyles.bRadiusMedium,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppStyles.mTextPrimary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppStyles.mTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachedFileTag extends StatelessWidget {
  final String fileName;
  final VoidCallback onRemove;

  const _AttachedFileTag({required this.fileName, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppStyles.mAccent.withValues(alpha: 0.2),
        borderRadius: AppStyles.bRadiusMedium,
        border: Border.all(color: AppStyles.mAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.fileText, size: 16, color: AppStyles.mTextPrimary),
          const SizedBox(width: 10),
          Text(
            fileName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppStyles.mTextPrimary,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRemove,
            child: Icon(LucideIcons.x, size: 16, color: AppStyles.mTextPrimary),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool enabled;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary
        ? (enabled ? AppStyles.mPrimary : AppStyles.mBackground)
        : AppStyles.mBackground.withValues(alpha: 0.4);
    final iconColor = isPrimary
        ? (enabled ? Colors.white : AppStyles.mTextSecondary)
        : AppStyles.mTextPrimary;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: isPrimary && enabled
              ? [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
    );
  }
}

/// A modern bouncing dots animation widget for typing/thinking indicators.
/// Each dot bounces with a staggered delay creating a wave effect.
class _BouncingDots extends StatefulWidget {
  final Color color;

  const _BouncingDots({required this.color});

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const double _dotSize = 8.0;
  static const double _spacing = 4.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Stagger each dot by 0.2 (200ms delay between dots)
            final delay = index * 0.2;
            final animationValue = (_controller.value + delay) % 1.0;

            // Use a sine curve for smooth bounce effect
            // Bounce only in the first half of the animation cycle
            double bounce = 0.0;
            if (animationValue < 0.5) {
              // Map 0.0-0.5 to 0.0-1.0-0.0 for a full bounce
              final t = animationValue * 2;
              bounce =
                  -8.0 * (4 * t * (1 - t)); // Parabolic bounce, max -8 pixels
            }

            return Container(
              margin: EdgeInsets.only(right: index < 2 ? _spacing : 0),
              child: Transform.translate(
                offset: Offset(0, bounce),
                child: Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(
                      alpha: 0.6 + (animationValue < 0.5 ? 0.4 : 0.0),
                    ),
                    shape: BoxShape.circle,
                    boxShadow: animationValue < 0.5
                        ? [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Expandable task card widget with dropdown for description and links
class _ExpandableTaskCard extends StatefulWidget {
  final Map<String, dynamic> task;
  final Color priorityColor;
  final String priorityLabel;
  final bool hasDetails;

  const _ExpandableTaskCard({
    required this.task,
    required this.priorityColor,
    required this.priorityLabel,
    required this.hasDetails,
  });

  @override
  State<_ExpandableTaskCard> createState() => _ExpandableTaskCardState();
}

class _ExpandableTaskCardState extends State<_ExpandableTaskCard> {
  bool _isExpanded = false;

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppStyles.mTextSecondary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: AppStyles.mTextSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppStyles.mTextPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppStyles.bRadiusMedium,
        border: Border(left: BorderSide(color: widget.priorityColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task name and priority badge
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.task['task'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.mTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.priorityColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.priorityLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Dates row
          Row(
            children: [
              _buildDetailItem(
                LucideIcons.calendar,
                'Due',
                widget.task['DueDate'] ?? '-',
              ),
              const SizedBox(width: 20),
              _buildDetailItem(
                LucideIcons.play,
                'Start',
                widget.task['dateOnCalendar'] ?? '-',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Time to complete
          _buildDetailItem(
            LucideIcons.clock,
            'Time',
            '${widget.task['TimeToComplete'] ?? '-'} Days',
          ),
          // Dropdown button for details (only if has description or links)
          if (widget.hasDetails) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: AppStyles.mBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExpanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: AppStyles.mTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isExpanded ? 'Hide details' : 'Show details',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.mTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Expandable description and links
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            // Description
            if (widget.task['Description'] != null &&
                widget.task['Description'].toString().isNotEmpty) ...[
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.mTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.task['Description'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.mTextPrimary,
                  height: 1.5,
                ),
              ),
            ],
            // Links
            if (widget.task['links'] != null &&
                widget.task['links'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(LucideIcons.link, size: 14, color: AppStyles.mPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.task['links'].toString(),
                      style: TextStyle(fontSize: 12, color: AppStyles.mPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
