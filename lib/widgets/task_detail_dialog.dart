import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../styles.dart';
import 'add_task_dialog.dart';

/// A beautiful modal dialog that shows full task details
class TaskDetailDialog extends StatelessWidget {
  final Map<String, dynamic> task;

  const TaskDetailDialog({super.key, required this.task});

  /// Shows the task detail dialog
  static Future<void> show(BuildContext context, Map<String, dynamic> task) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => TaskDetailDialog(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priority = task['priority'] is int
        ? task['priority']
        : int.tryParse(task['priority']?.toString() ?? '3') ?? 3;
    final priorityColor = AppStyles.getPriorityColor(priority);
    final isCompleted = task['isCompleted'] == true;
    final taskName = task['task']?.toString() ?? 'Untitled Task';
    final description = task['Description']?.toString();
    final startTime = task['start_time']?.toString();
    final endTime = task['end_time']?.toString();
    final dateOnCalendar = task['dateOnCalendar']?.toString();
    final dueDate = task['DueDate']?.toString();
    final timeToComplete = task['TimeToComplete'];
    final links = task['links']?.toString();

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.45,
        constraints: const BoxConstraints(maxWidth: 500, minWidth: 350),
        margin: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: AppStyles.mSurface,
          borderRadius: AppStyles.bRadiusMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: priorityColor.withValues(alpha: 0.1),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
          border: Border.all(
            color: priorityColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppStyles.bRadiusMedium,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with priority indicator
                _buildHeader(
                  context,
                  taskName,
                  priority,
                  priorityColor,
                  isCompleted,
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time info
                        if (startTime != null && startTime.isNotEmpty)
                          _buildInfoRow(
                            LucideIcons.clock,
                            'Time',
                            endTime != null && endTime.isNotEmpty
                                ? '$startTime - $endTime'
                                : startTime,
                            AppStyles.mAccent,
                          ),

                        // Date info
                        if (dateOnCalendar != null && dateOnCalendar.isNotEmpty)
                          _buildInfoRow(
                            LucideIcons.calendar,
                            'Date',
                            dateOnCalendar,
                            AppStyles.mPrimary,
                          ),

                        // Due date
                        if (dueDate != null &&
                            dueDate.isNotEmpty &&
                            dueDate != dateOnCalendar)
                          _buildInfoRow(
                            LucideIcons.calendarCheck,
                            'Due Date',
                            dueDate,
                            Colors.orange,
                          ),

                        // Time to complete
                        if (timeToComplete != null)
                          _buildInfoRow(
                            LucideIcons.timer,
                            'Estimated Time',
                            '$timeToComplete minutes',
                            AppStyles.mSecondary,
                          ),

                        // Priority
                        _buildInfoRow(
                          LucideIcons.flag,
                          'Priority',
                          _getPriorityLabel(priority),
                          priorityColor,
                        ),

                        // Description
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.mTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppStyles.mBackground.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: AppStyles.bRadiusSmall,
                            ),
                            child: Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppStyles.mTextPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],

                        // Links
                        if (links != null && links.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            LucideIcons.link,
                            'Links',
                            links,
                            AppStyles.mPrimary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer with actions
                _buildFooter(context, isCompleted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String taskName,
    int priority,
    Color priorityColor,
    bool isCompleted,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            priorityColor.withValues(alpha: 0.15),
            priorityColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: priorityColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Priority indicator
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? LucideIcons.checkCircle : LucideIcons.circle,
              color: priorityColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Text(
              taskName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppStyles.mTextPrimary,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x, size: 20),
            color: AppStyles.mTextSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppStyles.mTextSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.mTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppStyles.mBackground, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Edit button
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              AddTaskDialog.edit(context, task);
            },
            icon: const Icon(LucideIcons.edit, size: 16),
            label: Text('Edit'),
            style: TextButton.styleFrom(foregroundColor: AppStyles.mPrimary),
          ),
          Row(
            children: [
              // Toggle completion button
              TextButton.icon(
                onPressed: () {
                  final provider = context.read<DayCrafterProvider>();
                  final taskId = task['id']?.toString();
                  if (taskId != null) {
                    provider.toggleTaskCompletion(taskId);
                  }
                  Navigator.of(context).pop();
                },
                icon: Icon(
                  isCompleted ? LucideIcons.x : LucideIcons.check,
                  size: 18,
                ),
                label: Text(isCompleted ? 'Incomplete' : 'Complete'),
                style: TextButton.styleFrom(
                  foregroundColor: isCompleted
                      ? AppStyles.mTextSecondary
                      : AppStyles.mAccent,
                ),
              ),
              const SizedBox(width: 8),
              // Close button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.mPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'High Priority';
      case 2:
        return 'Medium-High Priority';
      case 3:
        return 'Medium Priority';
      case 4:
        return 'Medium-Low Priority';
      case 5:
        return 'Low Priority';
      default:
        return 'Priority $priority';
    }
  }
}
