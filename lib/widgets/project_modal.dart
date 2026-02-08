import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../styles.dart';
import '../l10n/app_localizations.dart';

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
  Color _selectedColor = const Color(0xFF7A8D9A); // Default Morandi Blue
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
                        AppLocalizations.of(context)!.newProject,
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
              _buildSectionLabel(AppLocalizations.of(context)!.projectName),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: !_showEmojiPicker,
                style: TextStyle(color: AppStyles.mTextPrimary),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.projectNameHint,
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
              _buildSectionLabel(AppLocalizations.of(context)!.color),
              const SizedBox(height: 10),
              _buildColorPicker(),
              const SizedBox(height: 20),

              // Emoji Picker (expandable)
              if (_showEmojiPicker) ...[
                _buildSectionLabel(AppLocalizations.of(context)!.chooseIcon),
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
                        AppLocalizations.of(context)!.cancel,
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
                        backgroundColor: _selectedColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppStyles.bRadiusSmall,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.createProject,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _selectedColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showEmojiPicker
                  ? _selectedColor
                  : _selectedColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: _showEmojiPicker
                ? [
                    BoxShadow(
                      color: _selectedColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  _selectedEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
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
    return Center(
      child: SizedBox(
        width: 350,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
              });
            },
            labelTypes: const [],
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.7,
            paletteType: PaletteType.hueWheel,
          ),
        ),
      ),
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
              indicatorColor: _selectedColor,
              iconColor: AppStyles.mTextSecondary,
              iconColorSelected: _selectedColor,
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
      final colorInt = _selectedColor.toARGB32();
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
