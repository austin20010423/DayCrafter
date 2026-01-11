import 'package:flutter/material.dart';
import '../styles.dart';

class ProjectModal extends StatefulWidget {
  final Function(String) onSubmit;

  const ProjectModal({super.key, required this.onSubmit});

  @override
  State<ProjectModal> createState() => _ProjectModalState();
}

class _ProjectModalState extends State<ProjectModal> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.bRadiusLarge),
      backgroundColor: AppStyles.mSurface,
      child: Container(
        padding: const EdgeInsets.all(40),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create New Project',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.mTextPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppStyles.mTextSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Give your project a name to get started with your AI PM.',
              style: TextStyle(color: AppStyles.mTextSecondary, fontSize: 15),
            ),
            const SizedBox(height: 32),
            Text(
              'Project Name',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppStyles.mTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: AppStyles.mTextPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Q4 Marketing Campaign',
                hintStyle: TextStyle(
                  color: AppStyles.mTextSecondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppStyles.mBackground.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: AppStyles.bRadiusMedium,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  widget.onSubmit(val.trim());
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.bRadiusMedium,
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
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_controller.text.trim().isNotEmpty) {
                        widget.onSubmit(_controller.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyles.mPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.bRadiusMedium,
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Create Project',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
