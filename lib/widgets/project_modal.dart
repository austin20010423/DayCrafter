import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../styles.dart';

/// Data class to hold project creation result
class ProjectCreationData {
  final String name;
  final String colorHex;
  final String emoji;

  ProjectCreationData({
    required this.name,
    required this.colorHex,
    required this.emoji,
  });
}

class ProjectModal extends StatefulWidget {
  final Function(ProjectCreationData) onSubmit;

  const ProjectModal({super.key, required this.onSubmit});

  @override
  State<ProjectModal> createState() => _ProjectModalState();
}

class _ProjectModalState extends State<ProjectModal> {
  final _controller = TextEditingController();

  // Predefined color palette (Morandi style)
  static const List<Color> _colors = [
    Color(0xFF7A8D9A), // Muted Blue
    Color(0xFFACB8A8), // Sage Green
    Color(0xFFD6BDBC), // Dusty Rose
    Color(0xFFE8B4B8), // Soft Pink
    Color(0xFFA8C5C5), // Teal
    Color(0xFFCFB997), // Sandy Gold
    Color(0xFFB8A9C9), // Lavender
    Color(0xFF9DB5B2), // Seafoam
    Color(0xFFD4A5A5), // Coral
    Color(0xFF8FA3BF), // Periwinkle
  ];

  int _selectedColorIndex = 0;
  String _selectedEmoji = '📁'; // Default emoji
  bool _showEmojiPicker = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.bRadiusLarge),
      backgroundColor: AppStyles.mSurface,
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Emoji button (clickable to open picker)
                      _buildEmojiButton(),
                      const SizedBox(width: 16),
                      Text(
                        'New Project',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.mTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppStyles.mTextSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Project Name
              _buildSectionLabel('Project Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: !_showEmojiPicker,
                style: TextStyle(color: AppStyles.mTextPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Q4 Marketing Campaign',
                  hintStyle: TextStyle(
                    color: AppStyles.mTextSecondary.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: AppStyles.mBackground.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: AppStyles.bRadiusSmall,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),

              // Color Selection
              _buildSectionLabel('Color'),
              const SizedBox(height: 10),
              _buildColorPicker(),
              const SizedBox(height: 20),

              // Emoji Picker (expandable)
              if (_showEmojiPicker) ...[
                _buildSectionLabel('Choose Icon'),
                const SizedBox(height: 10),
                _buildEmojiPickerWidget(),
                const SizedBox(height: 16),
              ],

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppStyles.bRadiusSmall,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppStyles.mTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colors[_selectedColorIndex],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppStyles.bRadiusSmall,
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Create Project',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiButton() {
    return GestureDetector(
      onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _colors[_selectedColorIndex].withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _showEmojiPicker
                ? _colors[_selectedColorIndex]
                : _colors[_selectedColorIndex].withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: _showEmojiPicker
              ? [
                  BoxShadow(
                    color: _colors[_selectedColorIndex].withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(_selectedEmoji, style: const TextStyle(fontSize: 26)),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppStyles.mSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _showEmojiPicker ? Icons.keyboard_arrow_up : Icons.edit,
                  size: 12,
                  color: AppStyles.mTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: AppStyles.mTextSecondary,
      ),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_colors.length, (index) {
        final isSelected = index == _selectedColorIndex;
        return GestureDetector(
          onTap: () => setState(() => _selectedColorIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _colors[index],
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _colors[index].withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildEmojiPickerWidget() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppStyles.mBackground.withValues(alpha: 0.5),
        borderRadius: AppStyles.bRadiusSmall,
      ),
      child: ClipRRect(
        borderRadius: AppStyles.bRadiusSmall,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            setState(() {
              _selectedEmoji = emoji.emoji;
              _showEmojiPicker = false;
            });
          },
          config: Config(
            height: 200,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              columns: 8,
              emojiSizeMax: 28,
              verticalSpacing: 0,
              horizontalSpacing: 0,
              gridPadding: const EdgeInsets.symmetric(horizontal: 8),
              backgroundColor: Colors.transparent,
              noRecents: Text(
                'No Recent Emojis',
                style: TextStyle(fontSize: 14, color: AppStyles.mTextSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            categoryViewConfig: CategoryViewConfig(
              initCategory: Category.OBJECTS,
              backgroundColor: Colors.transparent,
              indicatorColor: _colors[_selectedColorIndex],
              iconColor: AppStyles.mTextSecondary,
              iconColorSelected: _colors[_selectedColorIndex],
              categoryIcons: const CategoryIcons(
                recentIcon: Icons.access_time,
                smileyIcon: Icons.emoji_emotions_outlined,
                animalIcon: Icons.pets_outlined,
                foodIcon: Icons.fastfood_outlined,
                activityIcon: Icons.sports_soccer_outlined,
                travelIcon: Icons.directions_car_outlined,
                objectIcon: Icons.lightbulb_outline,
                symbolIcon: Icons.emoji_symbols_outlined,
                flagIcon: Icons.flag_outlined,
              ),
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            searchViewConfig: SearchViewConfig(
              backgroundColor: Colors.transparent,
              buttonIconColor: AppStyles.mTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_controller.text.trim().isNotEmpty) {
      final colorInt = _colors[_selectedColorIndex].toARGB32();
      widget.onSubmit(
        ProjectCreationData(
          name: _controller.text.trim(),
          colorHex: '#${colorInt.toRadixString(16).substring(2).toUpperCase()}',
          emoji: _selectedEmoji,
        ),
      );
      Navigator.pop(context);
    }
  }
}
