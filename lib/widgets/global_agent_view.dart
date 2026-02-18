import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/audio_service.dart';
import '../provider.dart';
import '../models.dart';
import '../styles.dart';

enum ViewMode { defaultMode, recording, upload }

class GlobalAgentView extends StatefulWidget {
  const GlobalAgentView({super.key});

  @override
  State<GlobalAgentView> createState() => _GlobalAgentViewState();
}

class _GlobalAgentViewState extends State<GlobalAgentView>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  bool _isInputHovered = false;
  bool _isInputFocused = false;
  bool _initialized = false;
  ViewMode _viewMode = ViewMode.defaultMode;
  String? _attachedFile;
  String? _attachedFilePath;
  String? _attachedFileType;
  int _timerSeconds = 0;
  Timer? _timer;

  // Input glow animation
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (_glowController != null) {
      _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );
    }
    _inputFocusNode.addListener(_onFocusChange);

    // Refresh briefing details on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_initialized) {
        context.read<DayCrafterProvider>().refreshBriefingDetails();
        setState(() => _initialized = true);
      }
    });
  }

  void _onFocusChange() {
    final focused = _inputFocusNode.hasFocus;
    if (focused != _isInputFocused) {
      setState(() => _isInputFocused = focused);
      _updateGlowAnimation();
    }
  }

  void _updateGlowAnimation() {
    if (_glowController == null) return;
    if (_isInputHovered || _isInputFocused) {
      _glowController!.repeat(reverse: true);
    } else {
      _glowController!.stop();
      _glowController!.animateTo(
        0.0,
        duration: const Duration(milliseconds: 400),
      );
    }
  }

  @override
  void dispose() {
    _glowController?.dispose();
    _inputFocusNode.removeListener(_onFocusChange);
    _inputFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();

    return Scaffold(
      backgroundColor: AppStyles.mBackground,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),

                    // Layer 3: Proactive Notification Layer (Morning Briefing)
                    _buildProactiveLayer(provider),
                    const SizedBox(height: 40),

                    // Chat History
                    _buildChatHistory(provider),
                  ],
                ),
              ),
            ),
          ),
          _buildContent(provider),
        ],
      ),
    );
  }

  Widget _buildContent(DayCrafterProvider provider) {
    switch (_viewMode) {
      case ViewMode.recording:
        return _buildRecordingView();
      case ViewMode.upload:
        return _buildUploadView();
      case ViewMode.defaultMode:
        return _buildChatInput(provider);
    }
  }

  Widget _buildProactiveLayer(DayCrafterProvider provider) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: _getBriefingGradient(
          provider.briefingWeather,
          provider.briefingLocation,
        ),
        borderRadius: AppStyles.bRadiusLarge,
        border: Border.all(color: AppStyles.mPrimary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.sparkles,
                color: AppStyles.mPrimary,
                size: 36,
              ), // Increased from 28
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Morning Briefing',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 36, // Slightly larger
                    fontWeight: FontWeight.w900, // Black/Extra Bold
                    color: AppStyles.mTextPrimary,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  provider.refreshBriefingDetails();
                },
                icon: const Icon(LucideIcons.refreshCw, size: 20),
                tooltip: 'Refresh Briefing',
              ),
              const SizedBox(width: 12),
              Text(
                '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: AppStyles.mTextSecondary,
                  fontSize: 14, // Smaller
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48), // Increased from 24
          Row(
            children: [
              Expanded(
                child: _BriefingItem(
                  icon: LucideIcons.cloudSun,
                  title: provider.briefingWeatherDetail.isNotEmpty
                      ? provider.briefingWeatherDetail
                      : provider.briefingWeather,
                  subtitle: provider.briefingLocation,
                ),
              ),
              Expanded(
                child: _BriefingItem(
                  icon: LucideIcons.calendar,
                  title: provider.nextEventInfo,
                  subtitle:
                      '${provider.getTasksForDate(DateTime.now()).length} Events Today',
                ),
              ),
              Expanded(
                child: _BriefingItem(
                  icon: LucideIcons.alertTriangle,
                  title:
                      '${provider.getTasksForDate(DateTime.now()).where((t) => t['status'] != 'Completed').length} Tasks Left Today',
                  subtitle: 'Scheduled for today',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LinearGradient _getBriefingGradient(String weather, String location) {
    // Location-aware color logic
    if (location.toLowerCase().contains('phoenix') ||
        weather.contains('Sunny')) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppStyles.isDarkMode
            ? [
                const Color(0xFF3C342F), // Dark warm slate
                const Color(0xFF2A3240), // Dark background
              ]
            : [
                const Color(0xFFFFF7ED), // Warm light orange
                Colors.white,
              ],
      );
    } else if (weather.contains('Rain')) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppStyles.isDarkMode
            ? [
                const Color(0xFF2C3440), // Dark cool slate
                const Color(0xFF2A3240), // Dark background
              ]
            : [
                const Color(0xFFF0F9FF), // Light blue
                Colors.white,
              ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppStyles.isDarkMode
          ? [
              const Color(0xFF313B4A), // Dark surface
              const Color(0xFF2A3240), // Dark background
            ]
          : [AppStyles.mSurface, Colors.white],
    );
  }

  Widget _buildChatHistory(DayCrafterProvider provider) {
    if (provider.globalMessages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ...provider.globalMessages.asMap().entries.map((entry) {
          final index = entry.key;
          final msg = entry.value;
          return _buildMessageBubble(
            msg,
            isStreaming:
                provider.isLoading &&
                index == provider.globalMessages.length - 1 &&
                msg.role == MessageRole.model,
          );
        }),
      ],
    );
  }

  Widget _buildMessageBubble(dynamic msg, {bool isStreaming = false}) {
    final isUser = msg.role == MessageRole.user;

    // Ported from ChatView Gemini style
    Widget aiContent;
    // Show animation if text is empty OR if it starts with explicit thinking indicator
    // This matches how provider updates text during tool execution
    if (!isUser &&
        (msg.text.isEmpty || msg.text.startsWith('*Thinking')) &&
        isStreaming) {
      aiContent = _buildThinkingAnimationContent();
    } else {
      aiContent = MarkdownBody(
        data: msg.text,
        selectable: true,
        onTapLink: (text, href, title) async {
          if (href != null) {
            final uri = Uri.parse(href);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            color: AppStyles.mTextPrimary,
            fontSize: 15,
            height: 1.6,
          ),
          strong: TextStyle(
            color: AppStyles.mTextPrimary,
            fontWeight: FontWeight.bold,
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: isUser
                  ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                  : const EdgeInsets.only(top: 8, bottom: 8),
              decoration: isUser
                  ? BoxDecoration(
                      color: AppStyles.mPrimary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : null,
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    SelectableText(
                      msg.text,
                      textAlign: isUser ? TextAlign.end : TextAlign.start,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    )
                  else
                    aiContent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingAnimationContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_BouncingDots(color: AppStyles.mPrimary)],
      ),
    );
  }

  Widget _buildChatInput(DayCrafterProvider provider) {
    final bool glowActive = _isInputHovered || _isInputFocused;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isInputHovered = true);
        _updateGlowAnimation();
      },
      onExit: (_) {
        setState(() => _isInputHovered = false);
        _updateGlowAnimation();
      },
      child: AnimatedBuilder(
        animation: _glowAnimation ?? kAlwaysDismissedAnimation,
        builder: (context, child) {
          final double glowValue = _glowAnimation?.value ?? 0.0;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 100, vertical: 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppStyles.mSurface,
              borderRadius: AppStyles.bRadiusLarge,
              border: Border.all(
                color: glowActive
                    ? AppStyles.mPrimary.withValues(
                        alpha: 0.4 + 0.4 * glowValue,
                      )
                    : AppStyles.mPrimary.withValues(alpha: 0.25),
                width: glowActive ? 2.0 + 0.5 * glowValue : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: glowActive ? 0.22 : 0.15,
                  ),
                  blurRadius: glowActive ? 60 : 40,
                  offset: Offset(0, glowActive ? 25 : 15),
                ),
                if (glowActive)
                  BoxShadow(
                    color: AppStyles.mPrimary.withValues(
                      alpha: 0.15 + 0.2 * glowValue,
                    ),
                    blurRadius: 20 + 15 * glowValue,
                    spreadRadius: 1 + 3 * glowValue,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_attachedFile != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppStyles.mPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _attachedFileType == 'voice'
                              ? LucideIcons.music
                              : LucideIcons.fileText,
                          size: 16,
                          color: AppStyles.mPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _attachedFile!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppStyles.mPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _attachedFile = null;
                              _attachedFilePath = null;
                              _attachedFileType = null;
                            });
                          },
                          child: Icon(
                            LucideIcons.x,
                            size: 14,
                            color: AppStyles.mPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _searchController,
                  focusNode: _inputFocusNode,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(fontSize: 16, color: AppStyles.mTextPrimary),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleGlobalSubmit(provider),
                  decoration: InputDecoration(
                    hintText: 'Ask anything...',
                    hintStyle: TextStyle(
                      color: AppStyles.mTextSecondary.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _InputActionButton(
                          icon: LucideIcons.paperclip,
                          label: 'Attach',
                          onTap: _showUploadPopup,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _IconButton(
                          icon: LucideIcons.mic,
                          onTap: _startRecording,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        _IconButton(
                          icon: provider.isLoading
                              ? LucideIcons.x
                              : LucideIcons.send,
                          onTap: () {
                            if (provider.isLoading) {
                              provider.cancelCurrentRequest();
                            } else {
                              _handleGlobalSubmit(provider);
                            }
                          },
                          isPrimary: !provider.isLoading,
                          isDanger: provider.isLoading,
                          size: 44,
                          enabled:
                              _searchController.text.isNotEmpty ||
                              _attachedFile != null ||
                              provider.isLoading,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleGlobalSubmit(DayCrafterProvider provider) {
    final text = _searchController.text.trim();
    if (text.isEmpty && _attachedFile == null) return;

    if (provider.isLoading) return;

    // Build attachments metadata
    List<Map<String, String>>? attachments;
    if (_attachedFile != null) {
      attachments = [
        {
          'name': _attachedFile!,
          'type': _attachedFileType ?? 'text',
          if (_attachedFilePath != null) 'path': _attachedFilePath!,
        },
      ];
    }

    String displayText = text;
    if (_attachedFile != null) {
      if (text.isEmpty) {
        displayText = '[Attached: $_attachedFile]';
      } else {
        displayText = '$displayText\n\n[Attached: $_attachedFile]';
      }
    }

    provider.sendGlobalMessage(displayText, attachments: attachments);
    _searchController.clear();
    setState(() {
      _attachedFile = null;
      _attachedFilePath = null;
      _attachedFileType = null;
      _viewMode = ViewMode.defaultMode;
    });
  }

  // File/Voice Ported methods
  Future<void> _pickVoiceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac', 'wma'],
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path;
        if (path != null) {
          if (!mounted) return;
          setState(() {
            _attachedFile = file.name;
            _attachedFilePath = path;
            _attachedFileType = 'voice';
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking voice file: $e');
    }
  }

  Future<void> _pickTextFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path;
        if (path != null) {
          if (!mounted) return;
          setState(() {
            _attachedFile = file.name;
            _attachedFilePath = path;
            _attachedFileType = 'text';
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking text file: $e');
    }
  }

  void _showUploadPopup() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppStyles.mSurface,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.bRadiusMedium),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload File',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.mTextPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _UploadOptionButton(
                    icon: LucideIcons.music,
                    label: 'Voice',
                    subtitle: 'MP3, WAV, M4A',
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickVoiceFile();
                    },
                  ),
                  const SizedBox(width: 16),
                  _UploadOptionButton(
                    icon: LucideIcons.fileText,
                    label: 'Text',
                    subtitle: 'TXT files',
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickTextFile();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppStyles.mTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startRecording() async {
    final provider = context.read<DayCrafterProvider>();
    final hasPermission = await AudioService.instance.hasPermission();

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      return;
    }

    setState(() {
      _viewMode = ViewMode.recording;
      _timerSeconds = 0;
    });

    provider.setRecording(true);
    await AudioService.instance.startRecording();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _timerSeconds++);
    });
  }

  void _stopRecording(bool save) async {
    _timer?.cancel();
    final provider = context.read<DayCrafterProvider>();
    provider.setRecording(false);

    final path = await AudioService.instance.stopRecording();

    setState(() {
      if (save && path != null) {
        provider.sendGlobalAudioMessage(path);
      }
      _viewMode = ViewMode.defaultMode;
    });
  }

  Widget _buildRecordingView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        margin: const EdgeInsets.symmetric(horizontal: 100, vertical: 24),
        decoration: BoxDecoration(
          color: AppStyles.mSurface,
          borderRadius: AppStyles.bRadiusLarge,
          border: Border.all(color: AppStyles.mPrimary.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recording Audio...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.mTextPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => _stopRecording(false),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _formatTime(_timerSeconds),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppStyles.mPrimary,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _IconButton(
                  icon: LucideIcons.check,
                  onTap: () => _stopRecording(true),
                  isPrimary: true,
                  size: 64,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadView() {
    // Already covered by _showUploadPopup for simplicity
    return const SizedBox.shrink();
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _BriefingItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BriefingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_BriefingItem> createState() => _BriefingItemState();
}

class _BriefingItemState extends State<_BriefingItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..setTranslationRaw(0.0, _isHovered ? -4.0 : 0.0, 0.0),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.mPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: AppStyles.mPrimary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.mTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppStyles.mTextSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_isHovered) ...[
                        const SizedBox(width: 8),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 14,
                          color: AppStyles.mPrimary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool enabled;
  final double size;
  final bool isDanger;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.enabled = true,
    this.size = 56,
    this.isDanger = false,
  });

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool canHover = widget.enabled;

    final bgColor = widget.isDanger
        ? (canHover && _isHovered ? Colors.red.shade700 : Colors.red)
        : (widget.isPrimary
              ? (widget.enabled
                    ? (canHover && _isHovered
                          ? AppStyles.mPrimary.withValues(alpha: 0.9)
                          : AppStyles.mPrimary)
                    : AppStyles.mBackground)
              : (canHover && _isHovered
                    ? AppStyles.mPrimary.withValues(alpha: 0.15)
                    : AppStyles.mPrimary.withValues(alpha: 0.08)));

    final iconColor = widget.isDanger
        ? Colors.white
        : (widget.isPrimary
              ? (widget.enabled ? Colors.white : AppStyles.mTextSecondary)
              : (canHover && _isHovered
                    ? AppStyles.mPrimary
                    : AppStyles.mTextPrimary));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        borderRadius: AppStyles.bRadiusSmall,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppStyles.bRadiusSmall,
            border: !widget.isPrimary && !widget.isDanger
                ? Border.all(
                    color: AppStyles.mPrimary.withValues(
                      alpha: _isHovered ? 0.4 : 0.2,
                    ),
                    width: 1.5,
                  )
                : null,
            boxShadow: (widget.isDanger || (widget.isPrimary && widget.enabled))
                ? [
                    BoxShadow(
                      color: bgColor.withValues(alpha: _isHovered ? 0.4 : 0.3),
                      blurRadius: _isHovered ? 16 : 12,
                      offset: Offset(0, _isHovered ? 6 : 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(widget.icon, color: iconColor, size: widget.size * 0.46),
        ),
      ),
    );
  }
}

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
            final delay = index * 0.2;
            final animationValue = (_controller.value + delay) % 1.0;

            double bounce = 0.0;
            if (animationValue < 0.5) {
              final t = animationValue * 2;
              bounce = -8.0 * (4 * t * (1 - t));
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

class _InputActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InputActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_InputActionButton> createState() => _InputActionButtonState();
}

class _InputActionButtonState extends State<_InputActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppStyles.bRadiusSmall,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppStyles.mPrimary.withValues(alpha: 0.2)
                : AppStyles.mPrimary.withValues(alpha: 0.08),
            borderRadius: AppStyles.bRadiusSmall,
            border: Border.all(
              color: AppStyles.mPrimary.withValues(
                alpha: _isHovered ? 0.4 : 0.2,
              ),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: AppStyles.mPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: AppStyles.mPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _UploadOptionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppStyles.bRadiusMedium,
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppStyles.mBackground.withValues(alpha: 0.5),
          borderRadius: AppStyles.bRadiusMedium,
          border: Border.all(
            color: AppStyles.mTextSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppStyles.mPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppStyles.mPrimary, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppStyles.mTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: AppStyles.mTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
