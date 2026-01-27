import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'DayCrafter'**
  String get appTitle;

  /// Settings title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Appearance section title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Language section title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Chinese language option
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chinese;

  /// Done button text
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Add task button
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTask;

  /// Add new task dialog title
  ///
  /// In en, this message translates to:
  /// **'Add New Task'**
  String get addNewTask;

  /// Edit task title
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// Task name field label
  ///
  /// In en, this message translates to:
  /// **'Task Name'**
  String get taskName;

  /// Description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Optional description label
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get descriptionOptional;

  /// Priority label
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Time label
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Start time label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTime;

  /// End time label
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endTime;

  /// Mark complete button
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get markComplete;

  /// Mark incomplete button
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get markIncomplete;

  /// Edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Today label
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Tomorrow label
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No tasks message
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get noTasks;

  /// Workspaces label
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get workspaces;

  /// Search placeholder
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Search tooltip with shortcut
  ///
  /// In en, this message translates to:
  /// **'Search (⌘K)'**
  String get searchShortcut;

  /// Notifications tooltip
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// New project button
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get newProject;

  /// Delete project button
  ///
  /// In en, this message translates to:
  /// **'Delete Project'**
  String get deleteProject;

  /// Delete project confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{projectName}\"? This action cannot be undone.'**
  String deleteProjectConfirm(String projectName);

  /// Project name field
  ///
  /// In en, this message translates to:
  /// **'Project Name'**
  String get projectName;

  /// Project section header
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// Calendar button
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// Agent navigation item
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agent;

  /// Dashboard navigation item
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Day view option
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// Week view option
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// Month view option
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// High priority label
  ///
  /// In en, this message translates to:
  /// **'High Priority'**
  String get highPriority;

  /// Medium priority label
  ///
  /// In en, this message translates to:
  /// **'Medium Priority'**
  String get mediumPriority;

  /// Low priority label
  ///
  /// In en, this message translates to:
  /// **'Low Priority'**
  String get lowPriority;

  /// Due date label
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// Estimated time label
  ///
  /// In en, this message translates to:
  /// **'Estimated Time'**
  String get estimatedTime;

  /// Minutes unit
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// Task name placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter task name...'**
  String get enterTaskName;

  /// Description placeholder
  ///
  /// In en, this message translates to:
  /// **'Add details...'**
  String get addDetails;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a task name'**
  String get pleaseEnterTaskName;

  /// Save changes button
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Default project name
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultProject;

  /// User plan label
  ///
  /// In en, this message translates to:
  /// **'Personal Plan'**
  String get personalPlan;

  /// About section title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Account section title
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Logout button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Logout confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
