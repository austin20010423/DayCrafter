import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../styles.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';

/// Dialog for adding or editing a task manually
class AddTaskDialog extends StatefulWidget {
  final DateTime? initialDate;
  final Map<String, dynamic>? existingTask;

  const AddTaskDialog({super.key, this.initialDate, this.existingTask});

  /// Show dialog to add a new task
  static Future<void> show(BuildContext context, {DateTime? initialDate}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => AddTaskDialog(initialDate: initialDate),
    );
  }

  /// Show dialog to edit an existing task
  static Future<void> edit(BuildContext context, Map<String, dynamic> task) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => AddTaskDialog(existingTask: task),
    );
  }

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _taskNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _priority = 3;

  bool _isManuallyScheduled = true;
  String? _selectedProjectId;
  bool _isInit = true;

  bool get isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final task = widget.existingTask!;
      _taskNameController.text = task['task']?.toString() ?? '';
      _descriptionController.text = task['Description']?.toString() ?? '';
      _selectedDate =
          _parseDate(task['dateOnCalendar']?.toString()) ?? DateTime.now();
      _startTime = _parseTime(task['start_time']?.toString());
      _endTime = _parseTime(task['end_time']?.toString());
      _priority = task['priority'] is int ? task['priority'] : 3;

      _isManuallyScheduled = task['isManuallyScheduled'] == true;
      _selectedProjectId = task['projectId']?.toString();
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      if (!isEditing) {
        _selectedProjectId = context.read<DayCrafterProvider>().activeProjectId;
      }
      _isInit = false;
    }
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _isManuallyScheduled = true;
        // Auto-set end time to 30 min later if not set
        if (_endTime == null) {
          final endMinutes = picked.hour * 60 + picked.minute + 30;
          _endTime = TimeOfDay(
            hour: (endMinutes ~/ 60) % 24,
            minute: endMinutes % 60,
          );
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _isManuallyScheduled = true;
      });
    }
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<DayCrafterProvider>();

    if (provider.projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please create a project to continue.'),
          backgroundColor: AppStyles.priorityHigh,
        ),
      );
      return;
    }

    final taskData = {
      'uuid': widget.existingTask?['uuid'],
      'id':
          widget.existingTask?['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'task': _taskNameController.text.trim(),
      'Description': _descriptionController.text.trim(),
      'dateOnCalendar': _selectedDate.toIso8601String().split('T')[0],
      'start_time': _startTime != null ? _formatTime(_startTime!) : null,
      'end_time': _endTime != null ? _formatTime(_endTime!) : null,
      'priority': _priority,

      'isManuallyScheduled': _isManuallyScheduled,
      'projectId': _selectedProjectId,
    };

    if (isEditing) {
      provider.updateTask(taskData);
    } else {
      provider.addManualTask(taskData);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        constraints: BoxConstraints(
          maxWidth: 450,
          minWidth: 320,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
          ],
        ),
        child: ClipRRect(
          borderRadius: AppStyles.bRadiusMedium,
          child: Material(
            color: Colors.transparent,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTaskNameField(),
                          const SizedBox(height: 16),
                          _buildDescriptionField(),
                          const SizedBox(height: 20),
                          _buildDateSelector(),
                          const SizedBox(height: 16),
                          _buildTimeSelectors(),

                          const SizedBox(height: 20),
                          _buildProjectSelector(),
                          const SizedBox(height: 20),
                          _buildPrioritySelector(),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppStyles.mPrimary.withValues(alpha: 0.1),
            AppStyles.mSecondary.withValues(alpha: 0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppStyles.mPrimary.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppStyles.mPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEditing ? LucideIcons.edit : LucideIcons.plus,
              color: AppStyles.mPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            isEditing ? l10n.editTask : l10n.addNewTask,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppStyles.mTextPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x, size: 20),
            color: AppStyles.mTextSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskNameField() {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      controller: _taskNameController,
      decoration: InputDecoration(
        labelText: l10n.taskName,
        hintText: l10n.enterTaskName,
        prefixIcon: Icon(
          LucideIcons.fileText,
          color: AppStyles.mPrimary,
          size: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppStyles.mPrimary),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.pleaseEnterTaskName;
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      controller: _descriptionController,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: l10n.descriptionOptional,
        hintText: l10n.addDetails,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Icon(
            LucideIcons.alignLeft,
            color: AppStyles.mTextSecondary,
            size: 18,
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppStyles.mTextSecondary.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, color: AppStyles.mPrimary, size: 18),
            const SizedBox(width: 12),
            Text(
              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 15, color: AppStyles.mTextPrimary),
            ),
            const Spacer(),
            Icon(
              LucideIcons.chevronRight,
              color: AppStyles.mTextSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelectors() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _selectStartTime,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppStyles.mTextSecondary.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.clock, color: AppStyles.mAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _startTime != null
                        ? _formatTime(_startTime!)
                        : l10n.startTime,
                    style: TextStyle(
                      fontSize: 14,
                      color: _startTime != null
                          ? AppStyles.mTextPrimary
                          : AppStyles.mTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            LucideIcons.arrowRight,
            color: AppStyles.mTextSecondary,
            size: 16,
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: _selectEndTime,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppStyles.mTextSecondary.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.clock, color: AppStyles.mAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _endTime != null ? _formatTime(_endTime!) : l10n.endTime,
                    style: TextStyle(
                      fontSize: 14,
                      color: _endTime != null
                          ? AppStyles.mTextPrimary
                          : AppStyles.mTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.priority,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppStyles.mTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (index) {
            final priority = index + 1;
            final isSelected = _priority == priority;
            final color = AppStyles.getPriorityColor(priority);

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _priority = priority),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : AppStyles.mTextSecondary.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.flag,
                        size: 16,
                        color: isSelected ? color : AppStyles.mTextSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$priority',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? color : AppStyles.mTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppStyles.mBackground)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _saveTask,
            icon: Icon(
              isEditing ? LucideIcons.check : LucideIcons.plus,
              size: 18,
            ),
            label: Text(isEditing ? l10n.saveChanges : l10n.addTask),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.mPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSelector() {
    final provider = context.watch<DayCrafterProvider>();
    final projects = provider.projects;
    final selectedProject = projects.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () =>
          projects.isNotEmpty ? projects.first : _createDefaultProject(),
    );

    // If projects are empty (shouldn't happen usually if logged in), handle safely
    // if (projects.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project', // TODO: Add to l10n
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppStyles.mTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {
            if (projects.isEmpty) {
              _showCreateProjectDialog();
            } else {
              _showProjectSelectionDialog(projects);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppStyles.mTextSecondary.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _parseColor(selectedProject.colorHex),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  selectedProject.name,
                  style: TextStyle(fontSize: 15, color: AppStyles.mTextPrimary),
                ),
                const Spacer(),
                Icon(
                  LucideIcons.chevronDown,
                  color: AppStyles.mTextSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Project _createDefaultProject() {
    return Project(
      id: 'default',
      name: 'Tap to Create Project',
      description: '',
      createdAt: '',
      colorHex: '#FF5252', // Red to warn user
      messages: [],
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return Colors.grey;
    }
  }

  void _showProjectSelectionDialog(List<Project> projects) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppStyles.mSurface,
        title: Text(
          'Select Project',
          style: TextStyle(color: AppStyles.mTextPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: projects.length + 1, // Add +1 for "Create New Project"
            itemBuilder: (context, index) {
              if (index == projects.length) {
                // "Create New Project" option
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppStyles.mPrimary.withValues(alpha: 0.15),
                    radius: 14,
                    child: Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: AppStyles.mPrimary,
                    ),
                  ),
                  title: Text(
                    'Create New Project',
                    style: TextStyle(
                      color: AppStyles.mPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreateProjectDialog();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }

              final project = projects[index];
              final isSelected = project.id == _selectedProjectId;
              return ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _parseColor(project.colorHex),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  project.name,
                  style: TextStyle(
                    color: isSelected
                        ? AppStyles.mPrimary
                        : AppStyles.mTextPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        LucideIcons.check,
                        color: AppStyles.mPrimary,
                        size: 18,
                      )
                    : null,
                onTap: () {
                  setState(() => _selectedProjectId = project.id);
                  Navigator.pop(ctx);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCreateProjectDialog() {
    final nameController = TextEditingController();

    Color selectedColor = const Color(0xFF7A8D9A);
    String selectedIcon = 'folder';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppStyles.mSurface,
            title: Text(
              'New Project',
              style: TextStyle(color: AppStyles.mTextPrimary),
            ),
            content: SizedBox(
              width: 400, // Fixed width for dialog stability
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: TextStyle(color: AppStyles.mTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Project Name',
                        hintStyle: TextStyle(color: AppStyles.mTextSecondary),
                        filled: true,
                        fillColor: AppStyles.mBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppStyles.mPrimary),
                        ),
                      ),
                      onSubmitted: (_) => _createProject(
                        ctx,
                        nameController.text,
                        '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                        selectedIcon,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Color',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.mTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 350,
                        height: 200, // Explicit height for color picker
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ColorPicker(
                            pickerColor: selectedColor,
                            onColorChanged: (color) {
                              setState(() {
                                selectedColor = color;
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
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Icon',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.mTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppStyles.mBackground.withValues(alpha: 0.5),
                        borderRadius: AppStyles.bRadiusSmall,
                      ),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: ProjectIcons.availableIcons.length,
                        itemBuilder: (context, index) {
                          final iconName = ProjectIcons.availableIcons[index];
                          final isSelected = selectedIcon == iconName;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                selectedIcon = iconName;
                              });
                            },
                            borderRadius: AppStyles.bRadiusSmall,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectedColor.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: AppStyles.bRadiusSmall,
                                border: Border.all(
                                  color: isSelected
                                      ? selectedColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                ProjectIcons.getIcon(iconName),
                                color: isSelected
                                    ? selectedColor
                                    : selectedColor.withValues(alpha: 0.5),
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppStyles.mTextSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => _createProject(
                  ctx,
                  nameController.text,
                  '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  selectedIcon,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.mPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createProject(
    BuildContext ctx,
    String name,
    String colorHex,
    String icon,
  ) async {
    if (name.trim().isEmpty) return;

    try {
      final provider = context.read<DayCrafterProvider>();
      final newProjectId = await provider.addProject(
        name,
        colorHex: colorHex,
        icon: icon,
      );

      if (ctx.mounted) {
        Navigator.pop(ctx); // Close creation dialog
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project "$name" created'),
            backgroundColor: AppStyles.mSecondary,
          ),
        );

        setState(() {
          _selectedProjectId = newProjectId;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create project'),
            backgroundColor: AppStyles.priorityHigh,
          ),
        );
      }
    }
  }
}
