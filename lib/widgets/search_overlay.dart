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

  List<Message> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

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

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
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
      final results = await provider.semanticSearch(query);

      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
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
    if (_results.isEmpty) {
      return _buildNoResultsState();
    }

    // Results list
    return _buildResultsList();
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

  Widget _buildResultsList() {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final message = _results[index];
        return _SearchResultCard(
          message: message,
          onTap: () {
            // TODO: Navigate to the message
            _closeOverlay();
          },
        );
      },
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
