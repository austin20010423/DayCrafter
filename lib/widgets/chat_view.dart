import 'dart:async';
import 'package:flutter/material.dart';
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
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppStyles.mTextPrimary,
                      fontSize: 15,
                      height: 1.6,
                    ),
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
    return SizedBox(
      height: 200, // Fixed height for cards
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.mBackground,
              borderRadius: AppStyles.bRadiusMedium,
              border: Border.all(color: AppStyles.mSurface, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['task'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.mTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Due: ${task['DueDate'] ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.mTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Priority: ${task['priority'] ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.mTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Time: ${task['TimeToComplete'] ?? ''}h',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.mTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    task['Description'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.mTextPrimary,
                      height: 1.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 4,
                  ),
                ),
                if (task['links'] != null && task['links'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Links: ${task['links']}',
                    style: TextStyle(fontSize: 10, color: AppStyles.mPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        },
      ),
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
