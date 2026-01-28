// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DayCrafter';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get lightMode => 'Light';

  @override
  String get darkMode => 'Dark';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get done => 'Done';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get addTask => 'Add Task';

  @override
  String get addNewTask => 'Add New Task';

  @override
  String get editTask => 'Edit Task';

  @override
  String get taskName => 'Task Name';

  @override
  String get description => 'Description';

  @override
  String get descriptionOptional => 'Description (Optional)';

  @override
  String get priority => 'Priority';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get startTime => 'Start';

  @override
  String get endTime => 'End';

  @override
  String get markComplete => 'Complete';

  @override
  String get markIncomplete => 'Incomplete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get noTasks => 'No tasks';

  @override
  String get workspaces => 'Workspaces';

  @override
  String get search => 'Search';

  @override
  String get searchShortcut => 'Search (⌘K)';

  @override
  String get notifications => 'Notifications';

  @override
  String get newProject => 'New Project';

  @override
  String get deleteProject => 'Delete Project';

  @override
  String deleteProjectConfirm(String projectName) {
    return 'Are you sure you want to delete \"$projectName\"? This action cannot be undone.';
  }

  @override
  String get projectName => 'Project Name';

  @override
  String get project => 'Project';

  @override
  String get calendar => 'Calendar';

  @override
  String get agent => 'Agent';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get day => 'Day';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get highPriority => 'High Priority';

  @override
  String get mediumPriority => 'Medium Priority';

  @override
  String get lowPriority => 'Low Priority';

  @override
  String get dueDate => 'Due Date';

  @override
  String get estimatedTime => 'Estimated Time';

  @override
  String get minutes => 'minutes';

  @override
  String get enterTaskName => 'Enter task name...';

  @override
  String get addDetails => 'Add details...';

  @override
  String get pleaseEnterTaskName => 'Please enter a task name';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get defaultProject => 'Default';

  @override
  String get personalPlan => 'Personal Plan';

  @override
  String get about => 'About';

  @override
  String get account => 'Account';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get color => 'Color';

  @override
  String get chooseIcon => 'Choose Icon';

  @override
  String get createProject => 'Create Project';

  @override
  String get projectNameHint => 'e.g. Q4 Marketing Campaign';

  @override
  String get addNewProject => 'Add New Project';
}
