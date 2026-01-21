import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';
import '../styles.dart';

/// A beautiful search overlay that shows when the search button is pressed.
/// Features a glassmorphic design with smooth animations and semantic search.
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({super.key});

  /// Shows the search overlay as a modal
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => const SearchOverlay(),
    );
  }

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Message> _messageResults = [];
  List<Map<String, dynamic>> _taskResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  // Date filter state
  String _selectedDateFilter = 'all'; // 'today', 'week', 'month', 'all'
  DateTime? _startDate;
  DateTime? _endDate;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _setDateFilter(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _selectedDateFilter = filter;
      switch (filter) {
        case 'today':
          _startDate = today;
          _endDate = today;
          break;
        case 'week':
          _startDate = today.subtract(Duration(days: today.weekday - 1));
          _endDate = _startDate!.add(const Duration(days: 6));
          break;
        case 'month':
          _startDate = DateTime(today.year, today.month, 1);
          _endDate = DateTime(today.year, today.month + 1, 0);
          break;
        default:
          _startDate = null;
          _endDate = null;
      }
    });

    // Re-run search if there's a query
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _messageResults = [];
        _taskResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final provider = context.read<DayCrafterProvider>();

      // Search messages (semantic search)
      final messageResults = await provider.semanticSearch(query);

      // Search tasks (text search with date filter)
      final taskResults = provider.searchTasks(
        query,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _messageResults = messageResults;
          _taskResults = taskResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messageResults = [];
          _taskResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _closeOverlay() {
    _animationController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _closeOverlay();
        }
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) => FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(scale: _scaleAnimation, child: child),
        ),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.55,
            constraints: const BoxConstraints(
              maxWidth: 680,
              minWidth: 400,
              maxHeight: 520,
            ),
            margin: const EdgeInsets.symmetric(vertical: 60),
            decoration: BoxDecoration(
              color: AppStyles.mSurface.withValues(alpha: 0.98),
              borderRadius: AppStyles.bRadiusMedium,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: AppStyles.mPrimary.withValues(alpha: 0.08),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
              border: Border.all(
                color: AppStyles.mPrimary.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: AppStyles.bRadiusMedium,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [_buildSearchHeader(), _buildResultsArea()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppStyles.mBackground.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search icon with gradient
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppStyles.mPrimary.withValues(alpha: 0.2),
                  AppStyles.mSecondary.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppStyles.bRadiusSmall,
            ),
            child: Icon(
              LucideIcons.search,
              size: 20,
              color: AppStyles.mPrimary,
            ),
          ),
          const SizedBox(width: 16),
          // Search input
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              style: TextStyle(
                fontSize: 16,
                color: AppStyles.mTextPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search messages, tasks, and notes...',
                hintStyle: TextStyle(
                  color: AppStyles.mTextSecondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: _performSearch,
              onChanged: (value) {
                // Debounce search for better UX
                if (value.length > 2) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (_searchController.text == value) {
                      _performSearch(value);
                    }
                  });
                }
              },
            ),
          ),
          // Search button
          _SearchActionButton(
            icon: LucideIcons.arrowRight,
            onPressed: () => _performSearch(_searchController.text),
            isPrimary: true,
          ),
          const SizedBox(width: 8),
          // Close button
          _SearchActionButton(
            icon: LucideIcons.x,
            onPressed: _closeOverlay,
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsArea() {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: _buildResultsContent(),
      ),
    );
  }

  Widget _buildResultsContent() {
    // Loading state
    if (_isSearching) {
      return _buildLoadingState();
    }

    // Empty state (no search yet)
    if (!_hasSearched) {
      return _buildEmptyState();
    }

    // No results
    if (_messageResults.isEmpty && _taskResults.isEmpty) {
      return _buildNoResultsState();
    }

    // Results list (combined)
    return _buildCombinedResultsList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppStyles.mPrimary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Searching...',
            style: TextStyle(color: AppStyles.mTextSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(
          LucideIcons.sparkles,
          size: 40,
          color: AppStyles.mPrimary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Text(
          'Semantic Search',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppStyles.mTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find messages by meaning, not just keywords',
          style: TextStyle(fontSize: 13, color: AppStyles.mTextSecondary),
        ),
        const SizedBox(height: 24),
        // Quick search suggestions
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _QuickSearchChip(
              label: 'meetings this week',
              onTap: () {
                _searchController.text = 'meetings this week';
                _performSearch('meetings this week');
              },
            ),
            _QuickSearchChip(
              label: 'important tasks',
              onTap: () {
                _searchController.text = 'important tasks';
                _performSearch('important tasks');
              },
            ),
            _QuickSearchChip(
              label: 'deadlines',
              onTap: () {
                _searchController.text = 'deadlines';
                _performSearch('deadlines');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.searchX,
            size: 48,
            color: AppStyles.mTextSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppStyles.mTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or check your spelling',
            style: TextStyle(fontSize: 13, color: AppStyles.mTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedResultsList() {
    return ListView(
      shrinkWrap: true,
      children: [
        // Date filter chips
        _buildDateFilterChips(),
        const SizedBox(height: 12),

        // Task results section
        if (_taskResults.isNotEmpty) ...[
          _buildSectionHeader('Tasks', _taskResults.length),
          const SizedBox(height: 8),
          ...List.generate(_taskResults.length, (index) {
            final task = _taskResults[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildTaskResultCard(task),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Message results section
        if (_messageResults.isNotEmpty) ...[
          _buildSectionHeader('Messages', _messageResults.length),
          const SizedBox(height: 8),
          ...List.generate(_messageResults.length, (index) {
            final message = _messageResults[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SearchResultCard(
                message: message,
                onTap: () => _closeOverlay(),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildDateFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DateFilterChip(
          label: 'All Time',
          isSelected: _selectedDateFilter == 'all',
          onTap: () => _setDateFilter('all'),
        ),
        _DateFilterChip(
          label: 'Today',
          isSelected: _selectedDateFilter == 'today',
          onTap: () => _setDateFilter('today'),
        ),
        _DateFilterChip(
          label: 'This Week',
          isSelected: _selectedDateFilter == 'week',
          onTap: () => _setDateFilter('week'),
        ),
        _DateFilterChip(
          label: 'This Month',
          isSelected: _selectedDateFilter == 'month',
          onTap: () => _setDateFilter('month'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppStyles.mTextSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppStyles.mPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppStyles.mPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskResultCard(Map<String, dynamic> task) {
    final priority = task['priority'] is int
        ? task['priority']
        : int.tryParse(task['priority']?.toString() ?? '3') ?? 3;
    final priorityColor = AppStyles.getPriorityColor(priority);
    final isCompleted = task['isCompleted'] == true;

    return Material(
      color: AppStyles.mBackground.withValues(alpha: 0.4),
      borderRadius: AppStyles.bRadiusSmall,
      child: InkWell(
        onTap: _closeOverlay,
        borderRadius: AppStyles.bRadiusSmall,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.checkSquare,
                  size: 16,
                  color: priorityColor,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['task']?.toString() ?? 'Untitled Task',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.mTextPrimary,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.calendar,
                          size: 12,
                          color: AppStyles.mTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task['dateOnCalendar']?.toString() ?? '-',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppStyles.mTextSecondary,
                          ),
                        ),
                        if (task['start_time'] != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            LucideIcons.clock,
                            size: 12,
                            color: AppStyles.mTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task['start_time']} - ${task['end_time'] ?? ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppStyles.mTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppStyles.mTextSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action button in search header
class _SearchActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _SearchActionButton({
    required this.icon,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary
          ? AppStyles.mPrimary.withValues(alpha: 0.15)
          : AppStyles.mBackground.withValues(alpha: 0.5),
      borderRadius: AppStyles.bRadiusSmall,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppStyles.bRadiusSmall,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 18,
            color: isPrimary ? AppStyles.mPrimary : AppStyles.mTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// Quick search suggestion chip
class _QuickSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSearchChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppStyles.mBackground.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.search,
                size: 14,
                color: AppStyles.mTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
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
    );
  }
}

/// Search result card
class _SearchResultCard extends StatelessWidget {
  final Message message;
  final VoidCallback onTap;

  const _SearchResultCard({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Material(
      color: AppStyles.mBackground.withValues(alpha: 0.4),
      borderRadius: AppStyles.bRadiusSmall,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.bRadiusSmall,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isUser
                      ? AppStyles.mAccent.withValues(alpha: 0.3)
                      : AppStyles.mPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isUser ? LucideIcons.user : LucideIcons.bot,
                  size: 16,
                  color: isUser ? AppStyles.mAccent : AppStyles.mPrimary,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUser ? 'You' : 'AI Assistant',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.mTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _truncateText(message.text, 120),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.mTextPrimary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppStyles.mTextSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow indicator
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppStyles.mTextSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// Date filter chip for search
class _DateFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppStyles.mPrimary.withValues(alpha: 0.2)
          : AppStyles.mBackground.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppStyles.mPrimary : AppStyles.mTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
