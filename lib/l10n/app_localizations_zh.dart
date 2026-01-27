// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'DayCrafter';

  @override
  String get settings => '設定';

  @override
  String get appearance => '外觀';

  @override
  String get language => '語言';

  @override
  String get lightMode => '淺色';

  @override
  String get darkMode => '深色';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get done => '完成';

  @override
  String get cancel => '取消';

  @override
  String get delete => '刪除';

  @override
  String get addTask => '新增任務';

  @override
  String get addNewTask => '新增任務';

  @override
  String get editTask => '編輯任務';

  @override
  String get taskName => '任務名稱';

  @override
  String get description => '描述';

  @override
  String get descriptionOptional => '描述（選填）';

  @override
  String get priority => '優先級';

  @override
  String get date => '日期';

  @override
  String get time => '時間';

  @override
  String get startTime => '開始';

  @override
  String get endTime => '結束';

  @override
  String get markComplete => '完成';

  @override
  String get markIncomplete => '未完成';

  @override
  String get edit => '編輯';

  @override
  String get close => '關閉';

  @override
  String get today => '今天';

  @override
  String get tomorrow => '明天';

  @override
  String get noTasks => '沒有任務';

  @override
  String get workspaces => '工作區';

  @override
  String get search => '搜尋';

  @override
  String get searchShortcut => '搜尋 (⌘K)';

  @override
  String get notifications => '通知';

  @override
  String get newProject => '新專案';

  @override
  String get deleteProject => '刪除專案';

  @override
  String deleteProjectConfirm(String projectName) {
    return '確定要刪除「$projectName」嗎？此操作無法復原。';
  }

  @override
  String get projectName => '專案名稱';

  @override
  String get project => '專案';

  @override
  String get calendar => '日曆';

  @override
  String get agent => '助理';

  @override
  String get dashboard => '儀表板';

  @override
  String get day => '日';

  @override
  String get week => '週';

  @override
  String get month => '月';

  @override
  String get highPriority => '高優先級';

  @override
  String get mediumPriority => '中優先級';

  @override
  String get lowPriority => '低優先級';

  @override
  String get dueDate => '截止日期';

  @override
  String get estimatedTime => '預計時間';

  @override
  String get minutes => '分鐘';

  @override
  String get enterTaskName => '輸入任務名稱...';

  @override
  String get addDetails => '新增詳情...';

  @override
  String get pleaseEnterTaskName => '請輸入任務名稱';

  @override
  String get saveChanges => '儲存變更';

  @override
  String get defaultProject => '預設';

  @override
  String get personalPlan => '個人方案';

  @override
  String get about => '關於';

  @override
  String get account => '帳號';

  @override
  String get logout => '登出';

  @override
  String get logoutConfirm => '確定要登出嗎？';
}
